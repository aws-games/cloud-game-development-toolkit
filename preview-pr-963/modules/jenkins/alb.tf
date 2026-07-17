################################################################################
# Load Balancer
################################################################################
resource "aws_lb" "jenkins_alb" {
  count              = var.create_application_load_balancer ? 1 : 0
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  subnets            = var.jenkins_alb_subnets
  security_groups    = concat(var.existing_security_groups, [aws_security_group.jenkins_alb_sg[0].id])

  dynamic "access_logs" {
    for_each = var.enable_jenkins_alb_access_logs ? [1] : []
    content {
      enabled = var.enable_jenkins_alb_access_logs
      bucket  = var.jenkins_alb_access_logs_bucket != null ? var.jenkins_alb_access_logs_bucket : aws_s3_bucket.jenkins_alb_access_logs_bucket[0].id
      prefix  = var.jenkins_alb_access_logs_prefix != null ? var.jenkins_alb_access_logs_prefix : "${local.name_prefix}-alb"
    }
  }

  enable_deletion_protection = var.enable_jenkins_alb_deletion_protection
  #checkov:skip=CKV_AWS_150:  Deletion protection is managed with a variable
  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing

  drop_invalid_header_fields = true

  tags = local.tags
}

resource "random_string" "jenkins_alb_access_logs_bucket_suffix" {
  count   = var.create_application_load_balancer && var.enable_jenkins_alb_access_logs && var.jenkins_alb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "jenkins_alb_access_logs_bucket" {
  count         = var.create_application_load_balancer && var.enable_jenkins_alb_access_logs && var.jenkins_alb_access_logs_bucket == null ? 1 : 0
  bucket        = "${local.name_prefix}-alb-access-logs-${random_string.jenkins_alb_access_logs_bucket_suffix[0].result}"
  force_destroy = var.debug

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary
  #checkov:skip=CKV2_AWS_6: Public access block configured separately
  #checkov:skip=CKV2_AWS_61: Lifecycle configuration configured separately

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.jenkins_alb_access_logs_bucket_suffix[0].result}"
  })
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = var.create_application_load_balancer && var.enable_jenkins_alb_access_logs && var.jenkins_alb_access_logs_bucket == null ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = [
      "${var.jenkins_alb_access_logs_bucket != null ? var.jenkins_alb_access_logs_bucket : aws_s3_bucket.jenkins_alb_access_logs_bucket[0].arn}/${var.jenkins_alb_access_logs_prefix != null ? var.jenkins_alb_access_logs_prefix : "${local.name_prefix}-alb"}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs_bucket_policy" {
  count  = var.create_application_load_balancer && var.enable_jenkins_alb_access_logs && var.jenkins_alb_access_logs_bucket == null ? 1 : 0
  bucket = var.jenkins_alb_access_logs_bucket == null ? aws_s3_bucket.jenkins_alb_access_logs_bucket[0].id : var.jenkins_alb_access_logs_bucket
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = var.create_application_load_balancer && var.enable_jenkins_alb_access_logs && var.jenkins_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.jenkins_alb_access_logs_bucket[0]
  ]
  bucket = aws_s3_bucket.jenkins_alb_access_logs_bucket[0].id
  rule {
    filter {
      prefix = ""
    }
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
  count = var.create_application_load_balancer && var.enable_jenkins_alb_access_logs && var.jenkins_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.jenkins_alb_access_logs_bucket[0]
  ]
  bucket                  = aws_s3_bucket.jenkins_alb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_lb_target_group" "jenkins_alb_target_group" {
  #checkov:skip=CKV_AWS_378: Using ALB for TLS termination
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/login"
    protocol            = "HTTP"
    matcher             = "200"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
  }

  tags = local.tags
}


# HTTPS listener for Jenkins ALB
resource "aws_lb_listener" "jenkins_alb_https_listener" {
  count             = var.create_application_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.jenkins_alb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.jenkins_alb_target_group.arn
    type             = "forward"
  }

  tags = local.tags
}
