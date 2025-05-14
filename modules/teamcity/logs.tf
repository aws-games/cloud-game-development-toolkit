# CloudWatch Logs
resource "aws_cloudwatch_log_group" "teamcity_log_group" {
  #checkov:skip=CKV_AWS_158: KMS Encryption disabled by default
  name              = "${local.name_prefix}-log-group"
  retention_in_days = var.teamcity_cloudwatch_log_retention_in_days
  tags              = local.tags
}

###########################
# Access Logs stored in S3 buckets
###########################

resource "random_string" "teamcity_alb_access_logs_bucket_suffix" {
  count   = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "teamcity_alb_access_logs_bucket" {
  count         = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  bucket        = "${local.name_prefix}-alb-access-logs-${random_string.teamcity_alb_access_logs_bucket_suffix[0].result}"
  force_destroy = var.debug

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.teamcity_alb_access_logs_bucket_suffix[0].result}"
  })
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = ["${var.teamcity_alb_access_logs_bucket != null ? var.teamcity_alb_access_logs_bucket : aws_s3_bucket.teamcity_alb_access_logs_bucket[0].arn}/${var.teamcity_alb_access_logs_prefix != null ? var.teamcity_alb_access_logs_prefix : "${local.name_prefix}-alb"}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs_bucket_policy" {
  count  = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  bucket = var.teamcity_alb_access_logs_bucket == null ? aws_s3_bucket.teamcity_alb_access_logs_bucket[0].id : var.teamcity_alb_access_logs_bucket
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.teamcity_alb_access_logs_bucket[0]
  ]
  bucket = aws_s3_bucket.teamcity_alb_access_logs_bucket[0].id
  rule {
    id     = "access-logs-lifecycle"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    expiration {
      days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs_bucket_public_block" {
  count = var.enable_teamcity_alb_access_logs && var.teamcity_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.teamcity_alb_access_logs_bucket[0]
  ]
  bucket                  = aws_s3_bucket.teamcity_alb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}