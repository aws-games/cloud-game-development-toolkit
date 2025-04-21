################################################################################
# Load Balancer
################################################################################
resource "aws_lb" "helix_swarm_alb" {
  count              = var.create_application_load_balancer ? 1 : 0
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  subnets            = var.helix_swarm_alb_subnets
  security_groups    = concat(var.existing_security_groups, [aws_security_group.helix_swarm_alb_sg[0].id])

  dynamic "access_logs" {
    for_each = (var.create_application_load_balancer && var.enable_helix_swarm_alb_access_logs ? [1] : [])
    content {
      enabled = var.enable_helix_swarm_alb_access_logs
      bucket = (var.helix_swarm_alb_access_logs_bucket != null ? var.helix_swarm_alb_access_logs_bucket :
      aws_s3_bucket.helix_swarm_alb_access_logs_bucket[0].id)
      prefix = (var.helix_swarm_alb_access_logs_prefix != null ? var.helix_swarm_alb_access_logs_prefix :
      "${local.name_prefix}-alb")
    }
  }

  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing

  enable_deletion_protection = var.enable_helix_swarm_alb_deletion_protection

  drop_invalid_header_fields = true

  tags = local.tags
}

resource "random_string" "helix_swarm_alb_access_logs_bucket_suffix" {
  count = (
    var.create_application_load_balancer && var.enable_helix_swarm_alb_access_logs && var.helix_swarm_alb_access_logs_bucket == null
  ? 1 : 0)
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "helix_swarm_alb_access_logs_bucket" {
  count = (
    var.create_application_load_balancer && var.enable_helix_swarm_alb_access_logs && var.helix_swarm_alb_access_logs_bucket == null
  ? 1 : 0)
  bucket = "${local.name_prefix}-alb-access-logs-${random_string.helix_swarm_alb_access_logs_bucket_suffix[0].result}"

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.helix_swarm_alb_access_logs_bucket_suffix[0].result}"
  })
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = (
    var.create_application_load_balancer && var.enable_helix_swarm_alb_access_logs && var.helix_swarm_alb_access_logs_bucket == null
  ? 1 : 0)
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = [
      "${var.helix_swarm_alb_access_logs_bucket != null ? var.helix_swarm_alb_access_logs_bucket : aws_s3_bucket.helix_swarm_alb_access_logs_bucket[0].arn}/${var.helix_swarm_alb_access_logs_prefix != null ? var.helix_swarm_alb_access_logs_prefix : "${local.name_prefix}-alb"}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs_bucket_policy" {
  count = (
    var.create_application_load_balancer && var.enable_helix_swarm_alb_access_logs && var.helix_swarm_alb_access_logs_bucket == null
  ? 1 : 0)
  bucket = (var.helix_swarm_alb_access_logs_bucket == null ? aws_s3_bucket.helix_swarm_alb_access_logs_bucket[0].id :
  var.helix_swarm_alb_access_logs_bucket)
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}


resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = (
    var.create_application_load_balancer && var.enable_helix_swarm_alb_access_logs && var.helix_swarm_alb_access_logs_bucket == null
  ? 1 : 0)
  bucket = aws_s3_bucket.helix_swarm_alb_access_logs_bucket[0].id
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
  count = (
    var.create_application_load_balancer && var.enable_helix_swarm_alb_access_logs && var.helix_swarm_alb_access_logs_bucket == null
    ? 1
  : 0)
  bucket                  = aws_s3_bucket.helix_swarm_alb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_lb_target_group" "helix_swarm_alb_target_group" {
  #checkov:skip=CKV_AWS_378: Using ALB for TLS termination
  name        = "${local.name_prefix}-tg"
  port        = var.helix_swarm_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200,401"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
  }

  tags = local.tags
}


# HTTPS listener for swarm ALB
resource "aws_lb_listener" "swarm_alb_https_listener" {
  count             = var.create_application_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.helix_swarm_alb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.helix_swarm_alb_target_group.arn
    type             = "forward"
  }

  tags = local.tags
}
