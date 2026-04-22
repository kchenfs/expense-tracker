variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, prod)"
  type        = string
}

variable "auth_lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function that generates pre-signed URLs"
  type        = string
}

variable "auth_lambda_function_name" {
  description = "Name of the Auth Lambda (needed to grant API Gateway invoke permissions)"
  type        = string
}