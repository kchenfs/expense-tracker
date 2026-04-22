resource "aws_sqs_queue" "queue" {
  name                      = "${var.queue_name}-${var.environment}"
  message_retention_seconds = var.message_retention_seconds

  # You can easily add default encryption or tags here later
  tags = {
    Environment = var.environment
  }
}