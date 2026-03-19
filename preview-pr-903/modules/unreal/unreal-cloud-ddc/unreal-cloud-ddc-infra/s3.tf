################################################################################
# S3
################################################################################
resource "aws_s3_bucket" "unreal_ddc_s3_bucket" {
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:This bucket doesnt have any triggers needed as its only an object store
  #checkov:skip=CKV_AWS_144:This bucket hosts ephemeral recreatable assets
  #checkov:skip=CKV_AWS_18:Logging bucket cna be configured by customer
  #checkov:skip=CKV_AWS_145:Causes issue with helm chart interacting with objects
  bucket_prefix = "${local.name_prefix}-s3-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "unreal_ddc_s3_acls" {
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# Scylla Monitoring NLB Access Logs Bucket
################################################################################
resource "random_string" "scylla_monitoring_lb_access_logs_bucket_suffix" {
  count   = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}
resource "aws_s3_bucket" "scylla_monitoring_lb_access_logs_bucket" {
  count         = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  bucket        = "${local.name_prefix}-alb-access-logs-${random_string.scylla_monitoring_lb_access_logs_bucket_suffix[0].result}"
  force_destroy = var.debug

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.scylla_monitoring_lb_access_logs_bucket_suffix[0].result}"
  })
}
resource "aws_s3_bucket_policy" "alb_access_logs_bucket_policy" {
  count  = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  bucket = var.scylla_monitoring_lb_access_logs_bucket == null ? aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].id : var.scylla_monitoring_lb_access_logs_bucket
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0]
  ]
  bucket = aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].id
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
  count = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0]
  ]
  bucket                  = aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
