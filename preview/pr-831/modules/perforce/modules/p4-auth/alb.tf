##########################################
# Application Load Balancer
##########################################
resource "aws_lb" "alb" {
  count                      = var.create_application_load_balancer ? 1 : 0
  name                       = var.application_load_balancer_name != null ? var.application_load_balancer_name : "${local.name_prefix}-alb"
  internal                   = var.internal
  load_balancer_type         = "application"
  subnets                    = var.alb_subnets
  security_groups            = concat(var.existing_security_groups, [aws_security_group.alb[0].id])
  enable_deletion_protection = var.enable_alb_deletion_protection
  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = (var.create_application_load_balancer && var.enable_alb_access_logs ? [1] :
    [])
    content {
      enabled = var.enable_alb_access_logs
      bucket = (var.alb_access_logs_bucket != null ?
        var.alb_access_logs_bucket :
      aws_s3_bucket.alb_access_logs_bucket[0].id)
      prefix = (var.alb_access_logs_prefix != null ?
      var.alb_access_logs_prefix : "${local.name_prefix}-alb")
    }
  }

  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing
  #checkov:skip=CKV_AWS_150: Deletion protection can be conditionally enabled


  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}


##########################################
# Application Load Balancer | Target Groups
##########################################
resource "aws_lb_target_group" "alb_target_group" {
  #checkov:skip=CKV_AWS_378: Using ALB for TLS termination
  name                 = "${local.name_prefix}-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = var.deregistration_delay # Fix LB listener from failing to be deleted because targets are still registered.
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

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-tg"
    }
  )

  # depends_on = [aws_ecs_service.service[0]]
}


##########################################
# Application Load Balancer | Listeners
##########################################
# HTTPS listener for p4_auth ALB
resource "aws_lb_listener" "alb_https_listener" {
  count             = var.create_application_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.alb_target_group.arn
    type             = "forward"
  }

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-tg-listener"
    }
  )

  depends_on = [aws_ecs_service.service]
}



##########################################
# Application Load Balancer | Logging
##########################################
resource "random_string" "alb_access_logs_bucket_suffix" {
  count = (
    var.create_application_load_balancer && var.enable_alb_access_logs && var.alb_access_logs_bucket == null
  ? 1 : 0)
  length  = 2
  special = false
  upper   = false
}

resource "aws_s3_bucket" "alb_access_logs_bucket" {
  count = (
    var.create_application_load_balancer && var.enable_alb_access_logs && var.alb_access_logs_bucket == null
  ? 1 : 0)
  bucket = "${local.name_prefix}-alb-access-logs-${random_string.alb_access_logs_bucket_suffix[0].result}"

  force_destroy = var.s3_enable_force_destroy

  #checkov:skip=CKV_AWS_21: Versioning not necessary for access logs
  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary for access logs
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.alb_access_logs_bucket_suffix[0].result}"
  })
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "access_logs_bucket_alb_write" {
  count = (
    var.create_application_load_balancer && var.enable_alb_access_logs && var.alb_access_logs_bucket == null
  ? 1 : 0)
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    resources = [
      "${var.alb_access_logs_bucket != null ? var.alb_access_logs_bucket : aws_s3_bucket.alb_access_logs_bucket[0].arn}/${var.alb_access_logs_prefix != null ? var.alb_access_logs_prefix : "${local.name_prefix}-alb"}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs_bucket_policy" {
  count = (
    var.create_application_load_balancer && var.enable_alb_access_logs && var.alb_access_logs_bucket == null
  ? 1 : 0)

  bucket = (var.alb_access_logs_bucket == null ?
    aws_s3_bucket.alb_access_logs_bucket[0].id :
  var.alb_access_logs_bucket)
  policy = data.aws_iam_policy_document.access_logs_bucket_alb_write[0].json
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_bucket_lifecycle_configuration" {
  count = (
    var.create_application_load_balancer && var.enable_alb_access_logs && var.alb_access_logs_bucket == null
  ? 1 : 0)
  depends_on = [
    aws_s3_bucket.alb_access_logs_bucket[0]
  ]
  bucket = aws_s3_bucket.alb_access_logs_bucket[0].id
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
  count = (
    var.create_application_load_balancer && var.enable_alb_access_logs && var.alb_access_logs_bucket == null
  ? 1 : 0)
  depends_on = [
    aws_s3_bucket.alb_access_logs_bucket[0]
  ]
  bucket                  = aws_s3_bucket.alb_access_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
