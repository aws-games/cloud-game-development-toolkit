################################################################################
# S3 Bucket (Assets)
################################################################################

resource "random_string" "assets_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "assets" {
  region        = var.region
  bucket        = "${local.name_prefix}-ddc-app-assets-${random_string.assets_suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "assets" {
  region = var.region
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  region = var.region
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}