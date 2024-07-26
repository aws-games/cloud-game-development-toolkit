################################################################################
# Load Balancer
################################################################################
resource "aws_lb" "helix_authentication_service_alb" {
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  subnets            = var.helix_authentication_service_alb_subnets
  security_groups    = concat(var.existing_security_groups, [aws_security_group.helix_authentication_service_alb_sg.id])

  dynamic "access_logs" {
    for_each = var.enable_helix_authentication_service_alb_access_logs ? [1] : []
    content {
      enabled = var.enable_helix_authentication_service_alb_access_logs
      bucket  = var.helix_authentication_service_alb_access_logs_bucket != null ? var.helix_authentication_service_alb_access_logs_bucket : aws_s3_bucket.helix_authentication_service_alb_access_logs_bucket[0].id
      prefix  = var.helix_authentication_service_alb_access_logs_prefix != null ? var.helix_authentication_service_alb_access_logs_prefix : "${local.name_prefix}-alb"
    }
  }
  enable_deletion_protection = var.enable_helix_authentication_service_alb_deletion_protection

  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing

  drop_invalid_header_fields = true

  tags = local.tags
}

resource "random_string" "helix_authentication_service_alb_access_logs_bucket_suffix" {
  count   = var.enable_helix_authentication_service_alb_access_logs && var.helix_authentication_service_alb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "helix_authentication_service_alb_access_logs_bucket" {
  count  = var.enable_helix_authentication_service_alb_access_logs && var.helix_authentication_service_alb_access_logs_bucket == null ? 1 : 0
  bucket = "${local.name_prefix}-alb-access-logs-${random_string.helix_authentication_service_alb_access_logs_bucket_suffix[0].result}"

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.helix_authentication_service_alb_access_logs_bucket_suffix[0].result}"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = var.enable_helix_authentication_service_alb_access_logs && var.helix_authentication_service_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.helix_authentication_service_alb_access_logs_bucket[0]
  ]
  bucket = aws_s3_bucket.helix_authentication_service_alb_access_logs_bucket[0].id
  rule {
    id     = "access-logs-lifecycle"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 60
      storage_class = "GLACIER"
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
  count = var.enable_helix_authentication_service_alb_access_logs && var.helix_authentication_service_alb_access_logs_bucket == null ? 1 : 0
  depends_on = [
    aws_s3_bucket.helix_authentication_service_alb_access_logs_bucket[0]
  ]
  bucket                  = aws_s3_bucket.helix_authentication_service_alb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_lb_target_group" "helix_authentication_service_alb_target_group" {
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/"
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


# HTTPS listener for helix_authentication_service ALB
resource "aws_lb_listener" "helix_authentication_service_alb_https_listener" {
  load_balancer_arn = aws_lb.helix_authentication_service_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.helix_authentication_service_alb_target_group.arn
    type             = "forward"
  }

  tags = local.tags
}
