output "bucket_id" {
  value = aws_s3_bucket.receipts.id
}

output "bucket_arn" {
  value = aws_s3_bucket.receipts.arn
}

output "bucket_name" {
  value = aws_s3_bucket.receipts.bucket
}