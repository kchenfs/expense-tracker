resource "aws_dynamodb_table" "expenses" {
  name             = "${var.table_name}-${var.environment}"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "ReceiptID"

  attribute {
    name = "ReceiptID"
    type = "S"
  }

  # Enable the Stream (Append-only mode)
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE" 

  tags = {
    Environment = var.environment
  }
}
