resource "aws_iam_role" "sfn_role" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "sfn_invoke_policy" {
  name = "${var.name}-invoke-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = var.lambda_arns
    }]
  })
}

resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/vendedlogs/states/${var.name}"
  retention_in_days = var.log_retention_in_days
}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name       = var.name
  role_arn   = aws_iam_role.sfn_role.arn
  definition = var.definition
  
  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = var.sfn_include_execution_data
    level                  = var.sfn_log_level
  }
}

resource "aws_iam_role_policy" "sfn_logging_policy" {
  # Only create this policy if logging is enabled
  count = var.sfn_log_level != "OFF" ? 1 : 0

  name = "${var.name}-logging-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "sfn_sqs_dlq_policy" {
  # CHANGED: Use the boolean toggle here
  count = var.enable_dlq ? 1 : 0 

  name = "${var.name}-sqs-dlq-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = var.dlq_queue_arn
    }]
  })
}