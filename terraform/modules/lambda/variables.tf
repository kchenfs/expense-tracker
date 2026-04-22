variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "source_dir" {
  description = "Path to the directory containing Lambda source code"
  type        = string
}

variable "handler" {
  description = "The entrypoint handler (e.g., main.handler)"
  type        = string
  default     = "main.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "environment_vars" {
  description = "Map of environment variables for the Lambda"
  type        = map(string)
  default     = {}
}

variable "custom_policy_arn" {
  description = "ARN of a custom IAM policy to attach to the Lambda role (optional)"
  type        = string
  default     = ""
}

variable "attach_custom_policy" {
  description = "Set to true if passing a custom_policy_arn"
  type        = bool
  default     = false
}

variable "timeout" {
  description = "The amount of time your Lambda Function has to run in seconds."
  type        = number
  default     = 10
}

variable "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime."
  type        = number
  default     = 128
}