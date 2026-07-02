# - Random String to prevent naming conflicts -
resource "random_string" "artifact_buckets" {
  length  = 4
  special = false
  upper   = false
}


resource "aws_s3_bucket" "artifact_buckets" {
  #checkov:skip=CKV2_AWS_61: Lifecycle configuration not currently supported
  #checkov:skip=CKV_AWS_21: Versioning configurable through variables
  #checkov:skip=CKV_AWS_144: Cross-region replication not currently supported
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary
  for_each      = var.artifact_buckets
  bucket        = "${var.project_prefix}-${each.value.name}-${random_string.artifact_buckets.result}"
  force_destroy = each.value.enable_force_destroy

  tags = merge(
    {
      "environment" = var.environment
    },
    each.value.tags,
  )
}

resource "aws_s3_bucket_versioning" "artifact_bucket_versioning" {
  for_each = var.artifact_buckets
  bucket   = aws_s3_bucket.artifact_buckets[each.key].id
  versioning_configuration {
    status = each.value.enable_versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts_bucket_public_block" {
  for_each = var.artifact_buckets
  bucket   = aws_s3_bucket.artifact_buckets[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
