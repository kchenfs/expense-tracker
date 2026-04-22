variable "name" {
  description = "Name of the Step Function state machine"
  type        = string
}

variable "definition" {
  description = "JSON definition of the state machine"
  type        = string
}

variable "lambda_arns" {
  description = "List of Lambda ARNs the state machine needs permission to invoke"
  type        = list(string)
}

variable "sfn_log_level" {
  description = "Defines what execution history events are logged. (ALL, ERROR, FATAL, OFF)"
  type        = string
  default     = "OFF"
}

variable "sfn_include_execution_data" {
  description = "Determines whether execution data is included in your log."
  type        = bool
  default     = false
}

# --- NEW VARIABLES ---
variable "log_retention_in_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
}

variable "dlq_queue_arn" {
  description = "ARN of the SQS Dead Letter Queue (Optional)"
  type        = string
  default     = ""
}

variable "enable_dlq" {
  description = "Set to true to grant the Step Function permission to write to a DLQ"
  type        = bool
  default     = false
}