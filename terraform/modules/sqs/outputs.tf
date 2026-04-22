output "queue_url" {
  description = "The URL of the SQS queue (needed for Step Functions API call)"
  value       = aws_sqs_queue.queue.url
}

output "queue_arn" {
  description = "The ARN of the SQS queue (needed for IAM policies)"
  value       = aws_sqs_queue.queue.arn
}