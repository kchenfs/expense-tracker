variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ca-central-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "frontend_origin" {
  description = "Allowed origin for API Gateway and S3 CORS"
  type        = string
}


variable "openrouter_api_key" {
  description = "API key for OpenRouter Nemotron model"
  type        = string
  sensitive   = true
}

variable "google_credentials_json" {
  description = "The raw JSON string of the Google Service Account key"
  type        = string
  sensitive   = true
}


variable "sheet_name" {
  description = "The name of the specific tab in Google Sheets to write to"
  type        = string
  default     = "Expenses"
  sensitive = true
}

variable "spreadsheet_id" {
  description = "the value of the spreadsheet id"
  type =  string
  sensitive = true
}

variable "telegram_token" {
  description = "The Bot API token from BotFather"
  type        = string
  sensitive   = true
}

variable "telegram_secret" {
  description = "Secret token to validate incoming Telegram webhooks"
  type        = string
  sensitive   = true
}