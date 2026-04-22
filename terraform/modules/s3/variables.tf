variable "bucket_name" {
  description = "Name of the S3 bucket for storing receipts"
  type        = string
}

variable "environment" {
  description = "Environment (e.g., dev, prod)"
  type        = string
}

variable "frontend_origin" {
  description = "Allowed origin for CORS (e.g., http://localhost:3000 or your frontend domain)"
  type        = string
  default     = "*"
}