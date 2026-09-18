# =============================================================================
# S3 — Durable fragment storage
# =============================================================================

resource "aws_s3_bucket" "fragments" {
  #checkov:skip=CKV_AWS_18: Access logging optional — can be added by user via bucket policy
  #checkov:skip=CKV_AWS_144: Cross-region replication not required — single-region deployment, edge pods handle distribution
  #checkov:skip=CKV_AWS_145: SSE-S3 (AES256) sufficient — KMS CMK adds cost with no security benefit for content-addressed blobs
  #checkov:skip=CKV_AWS_21: Versioning intentionally disabled — fragments are immutable content-addressed blobs, versioning adds cost with no benefit
  #checkov:skip=CKV2_AWS_62: Event notifications optional — not required for module operation
  bucket_prefix = "${var.name_prefix}-fragments-"
  force_destroy = var.enable_force_destroy

  tags = merge(var.tags, { Name = "${var.name_prefix}-fragments" })
}

resource "aws_s3_bucket_versioning" "fragments" {
  bucket = aws_s3_bucket.fragments.id
  versioning_configuration { status = "Disabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "fragments" {
  bucket = aws_s3_bucket.fragments.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "fragments" {
  bucket                  = aws_s3_bucket.fragments.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "fragments" {
  count  = var.intelligent_tiering_archive_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.fragments.id
  name   = "fragment-tiering"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = var.intelligent_tiering_archive_days
  }

  dynamic "tiering" {
    for_each = var.intelligent_tiering_deep_archive_days > var.intelligent_tiering_archive_days ? [1] : []
    content {
      access_tier = "DEEP_ARCHIVE_ACCESS"
      days        = var.intelligent_tiering_deep_archive_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "fragments" {
  bucket = aws_s3_bucket.fragments.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}
