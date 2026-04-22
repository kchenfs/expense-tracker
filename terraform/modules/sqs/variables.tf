variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, prod)"
  type        = string
}

variable "message_retention_seconds" {
  description = "How long to keep messages in the queue"
  type        = number
  default     = 1209600 # 14 days
}