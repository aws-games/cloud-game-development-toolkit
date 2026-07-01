# S3 Multi-Region Access Point infrastructure for Horde artifact storage

# --- S3 Buckets ---

resource "aws_s3_bucket" "primary" {
  count  = var.enable_mrap ? 1 : 0
  bucket = "horde-artifacts-${var.primary_region}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "primary" {
  count  = var.enable_mrap ? 1 : 0
  bucket = aws_s3_bucket.primary[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "secondary" {
  count    = var.enable_mrap ? 1 : 0
  provider = aws.secondary
  bucket   = "horde-artifacts-${var.secondary_region}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "secondary" {
  count    = var.enable_mrap ? 1 : 0
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- Multi-Region Access Point ---

resource "aws_s3control_multi_region_access_point" "horde" {
  count      = var.enable_mrap ? 1 : 0
  account_id = data.aws_caller_identity.current.account_id

  details {
    name = "horde-mrap"

    region {
      bucket            = aws_s3_bucket.primary[0].id
      bucket_account_id = data.aws_caller_identity.current.account_id
    }

    region {
      bucket            = aws_s3_bucket.secondary[0].id
      bucket_account_id = data.aws_caller_identity.current.account_id
    }
  }
}

# --- Replication IAM ---

data "aws_iam_policy_document" "replication_assume" {
  count = var.enable_mrap ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "replication_policy" {
  count = var.enable_mrap ? 1 : 0
  statement {
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.primary[0].arn,
      aws_s3_bucket.secondary[0].arn,
    ]
  }
  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = [
      "${aws_s3_bucket.primary[0].arn}/*",
      "${aws_s3_bucket.secondary[0].arn}/*",
    ]
  }
  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = [
      "${aws_s3_bucket.primary[0].arn}/*",
      "${aws_s3_bucket.secondary[0].arn}/*",
    ]
  }
}

resource "aws_iam_role" "replication_primary" {
  count              = var.enable_mrap ? 1 : 0
  name               = "horde-s3-replication-primary"
  assume_role_policy = data.aws_iam_policy_document.replication_assume[0].json
}

resource "aws_iam_role_policy" "replication_primary" {
  count  = var.enable_mrap ? 1 : 0
  name   = "replication"
  role   = aws_iam_role.replication_primary[0].id
  policy = data.aws_iam_policy_document.replication_policy[0].json
}

resource "aws_iam_role" "replication_secondary" {
  count              = var.enable_mrap ? 1 : 0
  name               = "horde-s3-replication-secondary"
  assume_role_policy = data.aws_iam_policy_document.replication_assume[0].json
}

resource "aws_iam_role_policy" "replication_secondary" {
  count  = var.enable_mrap ? 1 : 0
  name   = "replication"
  role   = aws_iam_role.replication_secondary[0].id
  policy = data.aws_iam_policy_document.replication_policy[0].json
}

# --- Replication Configuration ---

resource "aws_s3_bucket_replication_configuration" "primary_to_secondary" {
  count  = var.enable_mrap ? 1 : 0
  bucket = aws_s3_bucket.primary[0].id
  role   = aws_iam_role.replication_primary[0].arn

  rule {
    id     = "replicate-to-secondary"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.secondary[0].arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.secondary]
}

resource "aws_s3_bucket_replication_configuration" "secondary_to_primary" {
  count    = var.enable_mrap ? 1 : 0
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary[0].id
  role     = aws_iam_role.replication_secondary[0].arn

  rule {
    id     = "replicate-to-primary"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.primary[0].arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.secondary, aws_s3_bucket_versioning.primary]
}
