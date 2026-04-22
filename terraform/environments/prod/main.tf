module "receipts_bucket" {
  source          = "../../modules/s3"
  bucket_name     = "${var.project_name}-receipts"
  environment     = var.environment
  frontend_origin = var.frontend_origin
}

module "expenses_table" {
  source      = "../../modules/dynamodb"
  table_name  = "${var.project_name}-db"
  environment = var.environment
}

module "auth_lambda" {
  source        = "../../modules/lambda"
  function_name = "${var.project_name}-auth-presign-${var.environment}"
  source_dir    = "../../../lambdas/auth_presign"
  
  environment_vars = {
    RECEIPTS_BUCKET = module.receipts_bucket.bucket_name
  }
}

module "api_gateway" {
  source                    = "../../modules/api_gateway"
  api_name                  = "${var.project_name}-api"
  environment               = var.environment
  auth_lambda_invoke_arn    = module.auth_lambda.invoke_arn
  auth_lambda_function_name = module.auth_lambda.function_name
}