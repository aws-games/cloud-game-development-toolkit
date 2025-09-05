################################################################################
# DDC Network Load Balancers (Conditional Creation)
################################################################################



# Network Load Balancer (conditional creation based on presence)
resource "aws_lb" "nlb" {
  count = var.load_balancers_config.nlb != null ? 1 : 0
  name               = local.nlb_name
  load_balancer_type = "network"
  internal           = !var.load_balancers_config.nlb.internet_facing
  subnets            = var.load_balancers_config.nlb.subnets

  security_groups = concat(
    var.load_balancers_config.nlb.security_groups,

    var.ddc_infra_config != null ? [aws_security_group.nlb[0].id] : []
  )

  enable_deletion_protection = false

  dynamic "access_logs" {
    for_each = local.nlb_logging_enabled && local.logs_bucket_id != null ? [1] : []
    content {
      enabled = true
      bucket  = local.logs_bucket_id
      prefix  = "infrastructure/nlb"
    }
  }

  tags = merge(var.tags, {
    Name   = local.nlb_name
    Type   = "Network Load Balancer"
    Access = var.load_balancers_config.nlb.internet_facing ? "Internet-facing" : "Internal"
    Region = var.region
  })
}

# NLB Target Group (conditional - points to our EKS cluster)
resource "aws_lb_target_group" "nlb_target_group" {
  count = var.load_balancers_config.nlb != null ? 1 : 0
  
  name        = "${local.name_prefix}-nlb-tg-${local.name_suffix}"
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health/live" # DDC health endpoint for bring-your-own NLB
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-nlb-tg-${local.name_suffix}"
    Region = var.region
  })
}

# NLB HTTP Listener (conditional - forwards or redirects based on certificate availability)
resource "aws_lb_listener" "http" {
  count = var.load_balancers_config.nlb != null ? 1 : 0
  
  load_balancer_arn = aws_lb.nlb[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_target_group[0].arn
  }

  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-nlb-http-listener"
    Region = var.region
    Mode   = var.debug_mode == "enabled" ? "Debug" : "Production"
  })
}

# NLB HTTPS Listener (conditional creation)
resource "aws_lb_listener" "https" {
  count = var.load_balancers_config.nlb != null && var.load_balancers_config.nlb.internet_facing ? 1 : 0

  load_balancer_arn = aws_lb.nlb[0].arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_target_group[0].arn
  }

  tags = merge(var.tags, {
    Name     = "${local.name_prefix}-nlb-https-listener"
    Region   = var.region
    Security = "HTTPS-first"
  })
}

################################################################################
# NLB Target Group Attachments
################################################################################

# Target registration handled by AWS Load Balancer Controller via TargetGroupBinding
# in ddc-services module - no manual EC2 instance registration needed

################################################################################
# Security Warnings for HTTP-only Configuration
################################################################################

# Warning when using HTTP without HTTPS for internet-facing load balancers
locals {
  security_warning = var.load_balancers_config.nlb != null && var.load_balancers_config.nlb.internet_facing && var.certificate_arn == null && var.debug_mode == "disabled" ? "SECURITY WARNING: Internet-facing load balancer without HTTPS certificate. Provide certificate_arn or enable debug_mode for testing." : null
}



################################################################################
# S3 Bucket for NLB Access Logs (if needed)
################################################################################

################################################################################
# Centralized Logging S3 Bucket (DDC Module Standard)
################################################################################

# Single logging bucket for entire DDC module
resource "aws_s3_bucket" "logs" {
  count         = local.any_logging_enabled ? 1 : 0
  bucket        = local.logs_bucket_name
  force_destroy = true

  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-logs"
    Type   = "Centralized Logging"
    Region = var.region
  })
}

# S3 bucket policy for load balancer access logs
resource "aws_s3_bucket_policy" "logs_policy" {
  count  = local.any_logging_enabled ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id
  policy = data.aws_iam_policy_document.logs_policy[0].json
}

data "aws_iam_policy_document" "logs_policy" {
  count = local.any_logging_enabled ? 1 : 0

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

data "aws_elb_service_account" "main" {}

################################################################################
# CloudWatch Log Groups (Issue #726 Standard)
################################################################################

# Infrastructure logs (NLB, EKS)
resource "aws_cloudwatch_log_group" "infrastructure" {
  for_each = local.infrastructure_logging

  name              = "${local.log_base_prefix}/infrastructure/${each.key}"
  retention_in_days = each.value.retention_days

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${each.key}-infrastructure-logs"
    LogType     = "Infrastructure"
    Description = "${title(each.key)} infrastructure logs"
    Component   = each.key
  })
}

# Application logs (DDC)
resource "aws_cloudwatch_log_group" "application" {
  for_each = local.application_logging

  name              = "${local.log_base_prefix}/application/${each.key}"
  retention_in_days = each.value.retention_days

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${each.key}-application-logs"
    LogType     = "Application"
    Description = "${title(each.key)} application logs"
    Component   = each.key
  })
}

# Service logs (ScyllaDB)
resource "aws_cloudwatch_log_group" "service" {
  for_each = local.service_logging

  name              = "${local.log_base_prefix}/service/${each.key}"
  retention_in_days = each.value.retention_days

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${each.key}-service-logs"
    LogType     = "Service"
    Description = "${title(each.key)} service logs"
    Component   = each.key
  })
}





