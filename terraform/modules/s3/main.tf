resource "aws_s3_bucket" "receipts" {
  bucket = "${var.bucket_name}-${var.environment}"
}

resource "aws_s3_bucket_cors_configuration" "receipts_cors" {
  bucket = aws_s3_bucket.receipts.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = [var.frontend_origin]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}



resource "aws_s3_bucket_notification" "events" {
  bucket      = aws_s3_bucket.receipts.id
  eventbridge = true 
}

resource "aws_s3_bucket_lifecycle_configuration" "receipts_lifecycle" {
  bucket = aws_s3_bucket.receipts.id

  rule {
    id     = "archive-to-glacier-after-24h"
    status = "Enabled"

    filter {} 

    transition {
      days          = 1
      storage_class = "GLACIER_IR" # Glacier Instant Retrieval
    }
  }
}