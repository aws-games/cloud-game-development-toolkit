################################################################################
# Centralized Logging S3 Bucket (DDC Module Standard)
################################################################################

# Single logging bucket for entire DDC module
resource "aws_s3_bucket" "logs" {
  count         = var.enable_centralized_logging ? 1 : 0
  region        = local.region
  bucket        = local.logs_bucket_name
  force_destroy = true

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-logs"
    Type = "Centralized Logging"
  })
}

# S3 bucket policy for load balancer access logs
resource "aws_s3_bucket_policy" "logs_policy" {
  count  = var.enable_centralized_logging ? 1 : 0
  region = local.region
  bucket = aws_s3_bucket.logs[0].id
  policy = data.aws_iam_policy_document.logs_policy[0].json
}

data "aws_iam_policy_document" "logs_policy" {
  count = var.enable_centralized_logging ? 1 : 0

  # Allow ELB service account to write access logs
  statement {
    sid    = "AllowELBAccessLogs"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs[0].arn}/*"]
  }

  # Allow AWS services to write logs (broad permissions for simplicity)
  statement {
    sid    = "AllowAWSServicesLogs"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "logs.amazonaws.com",
        "vpc-flow-logs.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }
    actions = ["s3:PutObject", "s3:GetBucketAcl", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.logs[0].arn,
      "${aws_s3_bucket.logs[0].arn}/*"
    ]
  }
}

# ELB service account for access logs - REQUIRED even with EKS Auto Mode
# EKS Auto Mode creates LoadBalancer services that still need to write access logs
# to S3 buckets, so we need the regional ELB service account ARN for bucket policy
data "aws_elb_service_account" "main" {
  region = local.region
}

################################################################################
# CloudWatch Log Groups - Single Log Group for All Logs
################################################################################

# Single log group for all DDC logs (Kubernetes, ScyllaDB, NLB, etc.)
resource "aws_cloudwatch_log_group" "logs" {
  count             = var.enable_centralized_logging ? 1 : 0
  region            = local.region
  name              = "${local.log_prefix}-${local.region}"
  retention_in_days = var.log_retention_days

  tags = merge(local.default_tags, {
    Name     = local.log_prefix
    Category = "centralized-logging"
    LogType  = "all"
    Module   = "unreal-cloud-ddc"
  })
}





