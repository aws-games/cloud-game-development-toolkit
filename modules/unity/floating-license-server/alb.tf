####################################################
# ALB Security Group
####################################################

# Unity License Server ALB security group
resource "aws_security_group" "unity_license_server_alb_sg" {
  #checkov:skip=CKV2_AWS_5: Attached to ALB

  count       = var.create_alb ? 1 : 0
  name        = "${var.name}-alb-sg"
  vpc_id      = var.vpc_id
  description = "Unity License Server Application Load Balancer security group"

  tags = merge(var.tags, {
    Name = "${var.name}-alb-sg"
  })
}

# ALB egress rule for http dashboard traffic to the Unity License Server on desired port
resource "aws_vpc_security_group_egress_rule" "unity_license_server_alb_egress_service_8080" {
  count                        = var.create_alb ? 1 : 0
  security_group_id            = aws_security_group.unity_license_server_alb_sg[0].id
  referenced_security_group_id = aws_security_group.unity_license_server_sg[0].id
  description                  = "Allows HTTP traffic (dashboard) to the Unity License Server"
  from_port                    = var.unity_license_server_port
  to_port                      = var.unity_license_server_port
  ip_protocol                  = "TCP"
}

####################################################
# Application Load Balancer
####################################################

resource "aws_lb" "unity_license_server_alb" {
  #checkov:skip=CKV_AWS_150: Deletion protection disabled by default
  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing

  count              = var.create_alb ? 1 : 0
  name               = "${var.name}-alb"
  security_groups    = [aws_security_group.unity_license_server_alb_sg[0].id]
  load_balancer_type = "application"
  internal           = var.alb_is_internal
  subnets            = var.alb_subnets

  dynamic "access_logs" {
    for_each = var.enable_alb_access_logs ? [1] : []
    content {
      enabled = var.enable_alb_access_logs
      bucket  = var.alb_access_logs_bucket != null ? var.alb_access_logs_bucket : aws_s3_bucket.alb_access_logs_bucket[0].id
      prefix  = var.alb_access_logs_prefix != null ? var.alb_access_logs_prefix : "${var.name}-alb"
    }
  }

  enable_deletion_protection = var.enable_alb_deletion_protection
  drop_invalid_header_fields = true
  tags                       = var.tags
}

resource "aws_lb_target_group" "unity_license_server_tg" {
  #checkov:skip=CKV_AWS_378: Using ALB for TLS termination

  name        = "${var.name}-tg"
  port        = var.unity_license_server_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/v1/status"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    port                = 80
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_target_group_attachment" "unity_license_server" {
  count            = var.create_alb ? 1 : 0
  target_group_arn = aws_lb_target_group.unity_license_server_tg.arn
  target_id        = aws_instance.unity_license_server.private_ip
}

# ALB HTTPS Listener
resource "aws_lb_listener" "unity_license_server_https_dashboard_listener" {
  count             = var.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.unity_license_server_alb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.unity_license_server_tg.arn
  }
  tags = var.tags
}

# ALB HTTP to HTTPS redirect
resource "aws_lb_listener" "unity_license_server_https_dashboard_redirect" {
  count             = var.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.unity_license_server_alb[0].arn
  port              = var.unity_license_server_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

####################################################
# ALB Access Logs
####################################################

resource "random_string" "alb_access_logs_bucket_suffix" {
  count   = var.enable_alb_access_logs && var.alb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "alb_access_logs_bucket" {
  #checkov:skip=CKV_AWS_18:  S3 access logs not necessary
  #checkov:skip=CKV_AWS_21:  Versioning not necessary for access logs
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported

  count         = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == null ? 1 : 0
  bucket        = "${var.name}-alb-access-logs-${random_string.alb_access_logs_bucket_suffix[0].result}"
  force_destroy = false

  tags = merge(var.tags, {
    Name = "${var.name}-alb-access-logs-${random_string.alb_access_logs_bucket_suffix[0].result}"
  })
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == null ? 1 : 0

  statement {
    sid     = "AllowELBServiceAccount"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = [
      "${var.alb_access_logs_bucket != null ? var.alb_access_logs_bucket : aws_s3_bucket.alb_access_logs_bucket[0].arn}/${var.alb_access_logs_prefix != null ? var.alb_access_logs_prefix : "${var.name}-alb"}/*"
    ]
  }

  # Statement for logs delivery service to put objects
  statement {
    sid     = "AllowLogDeliveryToPutObject"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    resources = [
      "${var.alb_access_logs_bucket != null ? var.alb_access_logs_bucket : aws_s3_bucket.alb_access_logs_bucket[0].arn}/${var.alb_access_logs_prefix != null ? var.alb_access_logs_prefix : "${var.name}-alb"}/*"
    ]
  }

  # Statement for logs delivery service to get bucket ACL
  statement {
    sid     = "AllowLogDeliveryToGetBucketACL"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    resources = [
      var.alb_access_logs_bucket != null ? var.alb_access_logs_bucket : aws_s3_bucket.alb_access_logs_bucket[0].arn
    ]
  }
}

resource "aws_s3_bucket_policy" "lb_access_logs_bucket_policy" {
  count  = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == null ? 1 : 0
  bucket = var.alb_access_logs_bucket == null ? aws_s3_bucket.alb_access_logs_bucket[0].id : var.alb_access_logs_bucket
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == null && length(aws_s3_bucket.alb_access_logs_bucket) > 0 ? 1 : 0

  bucket = aws_s3_bucket.alb_access_logs_bucket[0].id

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

  depends_on = [
    aws_s3_bucket.alb_access_logs_bucket[0]
  ]
}

resource "aws_s3_bucket_public_access_block" "access_logs_bucket_public_block" {
  count = var.create_alb && var.enable_alb_access_logs && var.alb_access_logs_bucket == null ? 1 : 0

  bucket                  = aws_s3_bucket.alb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [
    aws_s3_bucket.alb_access_logs_bucket[0]
  ]
}
