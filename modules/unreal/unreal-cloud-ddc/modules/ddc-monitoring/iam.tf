################################################################################
# Scylla Monitoring Role
################################################################################

data "aws_iam_policy_document" "scylla_monitoring_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scylla_monitoring_role" {
  count              = var.create_scylla_monitoring_stack ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.scylla_monitoring_assume_role.json
  name_prefix        = "scylla-monitoring-"
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-monitoring-role"
  })
}

data "aws_iam_policy_document" "scylla_monitoring_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Name"
      values   = ["scylla-node*"] # Adjust this tag to match your Scylla node naming
    }
  }
}

resource "aws_iam_role_policy" "scylla_monitoring_policy" {
  count  = var.create_scylla_monitoring_stack ? 1 : 0
  name   = "${local.name_prefix}-scylla-monitoring-policy"
  role   = aws_iam_role.scylla_monitoring_role[count.index].id
  policy = data.aws_iam_policy_document.scylla_monitoring_policy_doc.json
}

################################################################################
# Scylla Monitoring ALB Access Logs Bucket Policy
################################################################################

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = var.enable_scylla_monitoring_lb_access_logs && var.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = ["${aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].arn}/${var.scylla_monitoring_lb_access_logs_prefix != null ? var.scylla_monitoring_lb_access_logs_prefix : "alb"}/*"]
  }
}