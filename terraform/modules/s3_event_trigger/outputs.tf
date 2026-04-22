output "event_rule_arn" {
  description = "The ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.this.arn
}

output "event_rule_name" {
  description = "The Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.this.name
}

output "dlq_queue_url" {
  description = "The URL of the EventBridge Dead Letter Queue"
  value       = aws_sqs_queue.eb_dlq.url
}

output "dlq_queue_arn" {
  description = "The ARN of the EventBridge Dead Letter Queue"
  value       = aws_sqs_queue.eb_dlq.arn
}

output "iam_role_arn" {
  description = "The ARN of the IAM role used by EventBridge"
  value       = aws_iam_role.eventbridge_sfn_role.arn
}