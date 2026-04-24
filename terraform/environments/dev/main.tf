module "receipts_bucket" {
  source          = "../../modules/s3"
  bucket_name     = "${lower(var.project_name)}-receipts" 
  environment     = var.environment
  frontend_origin = var.frontend_origin
}

module "receipt_trigger" {
  source            = "../../modules/s3_event_trigger"
  name              = "${var.project_name}-receipt-upload-${var.environment}"
  bucket_id         = module.receipts_bucket.bucket_id
  filter_prefix     = "raw_receipts/"
  state_machine_arn = module.step_function.state_machine_arn
}

module "expenses_table" {
  source      = "../../modules/dynamodb"
  table_name  = "${var.project_name}-db"
  environment = var.environment
}

module "dlq" {
  source      = "../../modules/sqs"
  queue_name  = "${var.project_name}-processing-dlq"
  environment = var.environment
}

# --- AUTH & API GATEWAY ---
resource "aws_iam_policy" "auth_s3_write" {
  name   = "${var.project_name}-auth-s3-write-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:PutObject"]
      Effect   = "Allow"
      Resource = "${module.receipts_bucket.bucket_arn}/*"
    }]
  })
}

# Keep the S3 write policy as is, just rename the resource for clarity
resource "aws_iam_policy" "telegram_s3_write" {
  name   = "${var.project_name}-telegram-s3-write-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:PutObject"]
      Effect   = "Allow"
      Resource = "${module.receipts_bucket.bucket_arn}/*"
    }]
  })
}

# Update the Lambda Module
module "telegram_ingest_lambda" {
  source               = "../../modules/lambda"
  function_name        = "${var.project_name}-telegram-ingest-${var.environment}"
  source_dir           = "../../../lambdas/telegram_ingest"
  attach_custom_policy = true
  custom_policy_arn    = aws_iam_policy.telegram_s3_write.arn
  
  environment_vars = { 
    S3_BUCKET_NAME = module.receipts_bucket.bucket_name
    TELEGRAM_TOKEN = var.telegram_token
    TELEGRAM_SECRET = var.telegram_secret
  }
}

resource "aws_lambda_function_url" "telegram_url" {
  function_name      = module.telegram_ingest_lambda.function_name
  authorization_type = "NONE" # Publicly accessible
}

# Important: Output this so you can set your Telegram Webhook
output "telegram_webhook_url" {
  value = aws_lambda_function_url.telegram_url.function_url
}


# --- OCR PARSER ---
resource "aws_iam_policy" "ocr_s3_read" {
  name   = "${var.project_name}-ocr-s3-read-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject"]
      Effect   = "Allow"
      Resource = "${module.receipts_bucket.bucket_arn}/*"
    }]
  })
}

module "ocr_lambda" {
  source               = "../../modules/lambda"
  function_name        = "${var.project_name}-ocr-parser-${var.environment}"
  source_dir           = "../../../lambdas/ocr_parser"
  attach_custom_policy = true
  custom_policy_arn    = aws_iam_policy.ocr_s3_read.arn
  environment_vars     = { OPENROUTER_API_KEY = var.openrouter_api_key }
  
  # NEW: Give the AI time and memory!
  timeout              = 500
  memory_size          = 512
}

# --- DB WRITER ---
resource "aws_iam_policy" "db_write_policy" {
  name   = "${var.project_name}-db-write-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "dynamodb:PutItem"
      Effect   = "Allow"
      Resource = module.expenses_table.table_arn
    }]
  })
}

module "db_writer_lambda" {
  source               = "../../modules/lambda"
  function_name        = "${var.project_name}-db-writer-${var.environment}"
  source_dir           = "../../../lambdas/db_writer"
  attach_custom_policy = true
  custom_policy_arn    = aws_iam_policy.db_write_policy.arn
  environment_vars     = { DYNAMODB_TABLE_NAME = module.expenses_table.table_name }
}


module "step_function" {
  source        = "../../modules/step_functions"
  name          = "${var.project_name}-processor-${var.environment}"
  
  lambda_arns   = [module.ocr_lambda.function_arn, module.db_writer_lambda.function_arn]
  
  # NEW: Pass the boolean toggle and the ARN
  enable_dlq    = true
  dlq_queue_arn = module.dlq.queue_arn 
  
  sfn_log_level              = "ALL"
  sfn_include_execution_data = true
  
  definition = jsonencode({
    Comment = "Receipt Processing Orchestrator"
    StartAt = "OCR_Extraction"
    States = {
      OCR_Extraction = {
        Type     = "Task"
        Resource = module.ocr_lambda.function_arn
        Retry = [{ ErrorEquals = ["States.ALL"], IntervalSeconds = 3, MaxAttempts = 2, BackoffRate = 2.0 }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error_details", Next = "Send_To_DLQ" }]
        Next  = "DB_Write" 
      }
      DB_Write = {
        Type     = "Task"
        Resource = module.db_writer_lambda.function_arn
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error_details", Next = "Send_To_DLQ" }]
        Next  = "Success"
      }
      Send_To_DLQ = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          "QueueUrl"      = module.dlq.queue_url
          "MessageBody.$" = "$" 
        }
        End = true
      }
      Success = { Type = "Succeed" }
    }
  })
}


module "google_credentials_secret" {
  source         = "../../modules/ssm_secure_param"
  name_prefix    = "${var.project_name}-sheets-${var.environment}"
  parameter_name = "/${var.project_name}/${var.environment}/google_credentials"
  secret_value   = var.google_credentials_json
}

module "sheets_sync_lambda" {
  source               = "../../modules/lambda"
  function_name        = "${var.project_name}-sheets-sync-${var.environment}"
  source_dir           = "../../../lambdas/sheets_sync"
  timeout              = 15 
  
  attach_custom_policy = true
  custom_policy_arn    = module.google_credentials_secret.read_policy_arn
  
  environment_vars = {
    SPREADSHEET_ID           = var.spreadsheet_id 
    GCP_CREDENTIALS_SSM_NAME = module.google_credentials_secret.parameter_name
    
    # NEW: Pass the Terraform variable into the Lambda environment
    SHEET_NAME               = var.sheet_name
  }
}

# The Pipe connecting the Stream directly to the Lambda
module "dynamo_to_sheets_pipe" {
  source     = "../../modules/eventbridge_pipe"
  name       = "${var.project_name}-db-to-sheets-${var.environment}"
  
  # Grab the Stream ARN from your updated DynamoDB module
  source_arn = module.expenses_table.stream_arn
  
  # Point it to your new Lambda
  target_arn = module.sheets_sync_lambda.function_arn
}

