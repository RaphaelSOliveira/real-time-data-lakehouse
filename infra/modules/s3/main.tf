# S3 bucket names are globally unique across all AWS accounts, so suffix
# the requested name with the account ID to avoid collisions.
data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.bucket_name
}

resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name

  tags = merge(var.common_tags, {
    Name = local.bucket_name
  })
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
