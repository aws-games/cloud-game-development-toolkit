################################################################################
# S3 Bucket (Kubernetes Manifests)
################################################################################

resource "random_string" "manifests_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "manifests" {
  region        = var.region
  bucket        = "${local.name_prefix}-ddc-infra-assets-${random_string.manifests_suffix.result}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "manifests" {
  region = var.region
  bucket = aws_s3_bucket.manifests.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "manifests" {
  region = var.region
  bucket = aws_s3_bucket.manifests.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

################################################################################
# S3 Bucket (DDC Storage)
################################################################################

resource "aws_s3_bucket" "unreal_ddc_s3_bucket" {
  region        = var.region
  bucket        = local.s3_bucket_name
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "unreal_ddc_s3_bucket_versioning" {
  region = var.region
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "unreal_ddc_s3_bucket_encryption" {
  region = var.region
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "unreal_ddc_s3_bucket_lifecycle" {
  region = var.region
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}