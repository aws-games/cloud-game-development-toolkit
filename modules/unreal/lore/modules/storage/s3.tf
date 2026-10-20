# =============================================================================
# S3 — Durable fragment storage
# =============================================================================

resource "aws_s3_bucket" "fragments" {
  #checkov:skip=CKV_AWS_18: Access logging optional — can be added by user via bucket policy
  #checkov:skip=CKV_AWS_144: Cross-region replication is optional (replication_destination_bucket_arn) — single-region deployments do not need it
  #checkov:skip=CKV_AWS_145: SSE-S3 (AES256) sufficient — KMS CMK adds cost with no security benefit for content-addressed blobs
  #checkov:skip=CKV_AWS_21: Versioning only when replicating — fragments are immutable content-addressed blobs, versioning adds cost with no benefit otherwise
  #checkov:skip=CKV2_AWS_62: Event notifications optional — not required for module operation
  bucket_prefix = "${var.name_prefix}-fragments-"
  force_destroy = var.enable_force_destroy

  tags = merge(var.tags, { Name = "${var.name_prefix}-fragments" })
}

locals {
  replication_enabled = var.enable_replication
}

# Versioning is off by default: fragments are immutable, content-addressed blobs. Cross-Region
# Replication requires it, so it is enabled only when a replication destination is set. A
# noncurrent version can then only arise when the same key is written twice with the same bytes
# (replication racing a local put), and the lifecycle rule below expires those after a day.
resource "aws_s3_bucket_versioning" "fragments" {
  bucket = aws_s3_bucket.fragments.id
  versioning_configuration { status = local.replication_enabled ? "Enabled" : "Disabled" }
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

  dynamic "rule" {
    for_each = local.replication_enabled ? [1] : []
    content {
      id     = "expire-duplicate-versions"
      status = "Enabled"
      filter {}

      noncurrent_version_expiration { noncurrent_days = 1 }
    }
  }
}

# =============================================================================
# Cross-Region Replication (optional) — fragments only
# =============================================================================

data "aws_iam_policy_document" "replication_assume" {
  count = local.replication_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count              = local.replication_enabled ? 1 : 0
  name_prefix        = "${var.name_prefix}-s3-repl-"
  assume_role_policy = data.aws_iam_policy_document.replication_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "replication" {
  count = local.replication_enabled ? 1 : 0

  statement {
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.fragments.arn]
  }
  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.fragments.arn}/*"]
  }
  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = ["${var.replication_destination_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "replication" {
  count  = local.replication_enabled ? 1 : 0
  name   = "fragment-replication"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

# Ordering handle: the destination's versioning lives in another module instance.
resource "terraform_data" "replication_destination_ready" {
  count = local.replication_enabled ? 1 : 0
  input = var.replication_destination_ready
}

resource "aws_s3_bucket_replication_configuration" "fragments" {
  count  = local.replication_enabled ? 1 : 0
  bucket = aws_s3_bucket.fragments.id
  role   = aws_iam_role.replication[0].arn

  rule {
    id     = "fragments-to-replica-region"
    status = "Enabled"
    filter {}

    delete_marker_replication { status = "Disabled" }

    destination {
      bucket = var.replication_destination_bucket_arn

      dynamic "replication_time" {
        for_each = var.replication_time_control ? [1] : []
        content {
          status = "Enabled"
          time { minutes = 15 }
        }
      }

      dynamic "metrics" {
        for_each = var.replication_time_control ? [1] : []
        content {
          status = "Enabled"
          event_threshold { minutes = 15 }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.fragments, terraform_data.replication_destination_ready]
}
