# 1. Create the CloudWatch Log Group (1 Day Retention)
resource "aws_cloudwatch_log_group" "pipe_logs" {
  name              = "/aws/pipes/${var.name}"
  retention_in_days = 1
}

resource "aws_iam_role" "pipe_role" {
  name = "${var.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "pipes.amazonaws.com" }
    }]
  })
}

# Permission to read from the DynamoDB Stream
resource "aws_iam_role_policy" "pipe_source" {
  name = "PipeSourceDynamoDB"
  role = aws_iam_role.pipe_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams"
      ]
      Resource = var.source_arn
    }]
  })
}

# Permission to invoke the Lambda
resource "aws_iam_role_policy" "pipe_target" {
  name = "PipeTargetLambda"
  role = aws_iam_role.pipe_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = var.target_arn
    }]
  })
}

# 2. Permission to write to CloudWatch Logs
resource "aws_iam_role_policy" "pipe_logging" {
  name = "PipeLogging"
  role = aws_iam_role.pipe_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      # Note: We append :* to allow creation of stream resources under this group
      Resource = "${aws_cloudwatch_log_group.pipe_logs.arn}:*"
    }]
  })
}

resource "aws_pipes_pipe" "this" {
  name     = var.name
  role_arn = aws_iam_role.pipe_role.arn
  source   = var.source_arn
  target   = var.target_arn

  source_parameters {
    dynamodb_stream_parameters {
      starting_position = "LATEST"
      batch_size        = 10
      # Automatic retry logic if the Google API goes down
      maximum_retry_attempts = 3
    }
  }

  # 3. Enable Super Detailed Logging
  log_configuration {
    level                  = "TRACE" # Logs every step (INFO only logs start/finish, ERROR only logs failures)
    include_execution_data = ["ALL"]    # Captures the actual JSON payload being transformed

    cloudwatch_logs_log_destination {
      log_group_arn = aws_cloudwatch_log_group.pipe_logs.arn
    }
  }
}