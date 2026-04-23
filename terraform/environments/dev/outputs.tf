

output "s3_bucket_name" {
  description = "The name of the S3 bucket storing receipts"
  value       = module.receipts_bucket.bucket_name
}
