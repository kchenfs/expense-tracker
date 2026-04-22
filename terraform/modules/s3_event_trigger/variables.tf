variable "name" {
  description = "Name for the EventBridge rule and IAM role"
  type        = string
}

variable "bucket_id" {
  description = "The ID/Name of the S3 bucket to watch"
  type        = string
}

variable "filter_prefix" {
  description = "The S3 prefix to filter on (e.g., raw_receipts/)"
  type        = string
}

variable "state_machine_arn" {
  description = "The ARN of the Step Function to trigger"
  type        = string
}