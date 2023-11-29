terraform {
  required_version = ">=1.6, <1.7"
}
resource "aws_s3_bucket" "bucket" {
  bucket_prefix = var.state_bucket_prefix
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_s3_bucket_versioning" "_" {
  bucket = aws_s3_bucket.bucket.bucket
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "_" {
  bucket = aws_s3_bucket.bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_dynamodb_table" "state_lock_table" {
  name         = var.state_lock_table
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "LockID"
    type = "S"
  }
}
