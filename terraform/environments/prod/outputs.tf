output "api_endpoint" {
  description = "The URL of the API Gateway to hit from the frontend"
  value       = module.api_gateway.api_endpoint
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket storing receipts"
  value       = module.receipts_bucket.bucket_name
}