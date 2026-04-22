# 1. The Event Rule
resource "aws_cloudwatch_event_rule" "this" {
  name        = var.name
  description = "Trigger Step Function ${var.state_machine_arn} on S3 upload to ${var.bucket_id}"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [var.bucket_id]
      }
      object = {
        key = [{ prefix = var.filter_prefix }]
      }
    }
  })
}

# 2. The Dead Letter Queue (Delivery Layer)
resource "aws_sqs_queue" "eb_dlq" {
  name = "${var.name}-eb-dlq"
}

# 3. The Target (Merged into one block)
resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "TriggerStepFunction"
  arn       = var.state_machine_arn
  role_arn  = aws_iam_role.eventbridge_sfn_role.arn

  # The DLQ configuration lives here inside the single target block
  dead_letter_config {
    arn = aws_sqs_queue.eb_dlq.arn
  }
}

# 4. IAM Role for EventBridge
resource "aws_iam_role" "eventbridge_sfn_role" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "eb_start_sfn" {
  name = "AllowEventBridgeToStartSFN"
  role = aws_iam_role.eventbridge_sfn_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "states:StartExecution"
      Effect   = "Allow"
      Resource = var.state_machine_arn
    }]
  })
}

# 5. Permission for EventBridge to write to its DLQ
resource "aws_sqs_queue_policy" "eb_dlq_policy" {
  queue_url = aws_sqs_queue.eb_dlq.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.eb_dlq.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.this.arn }
      }
    }]
  })
}