# S3 Multi-Region Access Point infrastructure for Horde artifact storage

# --- S3 Buckets ---

resource "aws_s3_bucket" "primary" {
  bucket = "horde-artifacts-${var.primary_region}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = "horde-artifacts-${var.secondary_region}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- Multi-Region Access Point ---

resource "aws_s3control_multi_region_access_point" "horde" {
  account_id = data.aws_caller_identity.current.account_id

  details {
    name = "horde-mrap"

    region {
      bucket            = aws_s3_bucket.primary.id
      bucket_account_id = data.aws_caller_identity.current.account_id
    }

    region {
      bucket            = aws_s3_bucket.secondary.id
      bucket_account_id = data.aws_caller_identity.current.account_id
    }
  }
}

# --- Replication IAM ---

data "aws_iam_policy_document" "replication_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "replication_policy" {
  statement {
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.primary.arn,
      aws_s3_bucket.secondary.arn,
    ]
  }
  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = [
      "${aws_s3_bucket.primary.arn}/*",
      "${aws_s3_bucket.secondary.arn}/*",
    ]
  }
  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = [
      "${aws_s3_bucket.primary.arn}/*",
      "${aws_s3_bucket.secondary.arn}/*",
    ]
  }
}

resource "aws_iam_role" "replication_primary" {
  name               = "horde-s3-replication-primary"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

resource "aws_iam_role_policy" "replication_primary" {
  name   = "replication"
  role   = aws_iam_role.replication_primary.id
  policy = data.aws_iam_policy_document.replication_policy.json
}

resource "aws_iam_role" "replication_secondary" {
  name               = "horde-s3-replication-secondary"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

resource "aws_iam_role_policy" "replication_secondary" {
  name   = "replication"
  role   = aws_iam_role.replication_secondary.id
  policy = data.aws_iam_policy_document.replication_policy.json
}

# --- Replication Configuration ---

resource "aws_s3_bucket_replication_configuration" "primary_to_secondary" {
  bucket = aws_s3_bucket.primary.id
  role   = aws_iam_role.replication_primary.arn

  rule {
    id     = "replicate-to-secondary"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.secondary.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.secondary]
}

resource "aws_s3_bucket_replication_configuration" "secondary_to_primary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id
  role     = aws_iam_role.replication_secondary.arn

  rule {
    id     = "replicate-to-primary"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.primary.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.secondary, aws_s3_bucket_versioning.primary]
}
