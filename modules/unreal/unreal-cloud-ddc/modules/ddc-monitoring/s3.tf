################################################################################
# Scylla Monitoring ALB Access Logs Bucket
################################################################################
resource "random_string" "scylla_monitoring_lb_access_logs_bucket_suffix" {
  count   = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "scylla_monitoring_lb_access_logs_bucket" {
  count         = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  region        = var.region
  bucket        = "${local.name_prefix}-alb-access-logs-${random_string.scylla_monitoring_lb_access_logs_bucket_suffix[0].result}"
  force_destroy = true

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.scylla_monitoring_lb_access_logs_bucket_suffix[0].result}"
  })
}

resource "aws_s3_bucket_policy" "alb_access_logs_bucket_policy" {
  count  = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  region = var.region
  bucket = aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].id
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count  = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  region = var.region
  depends_on = [
    aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0]
  ]
  bucket = aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].id
  rule {
    id     = "access-logs-lifecycle"
    status = "Enabled"
    
    filter {
      prefix = ""
    }
    
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
  count  = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  region = var.region
  depends_on = [
    aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0]
  ]
  bucket                  = aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}