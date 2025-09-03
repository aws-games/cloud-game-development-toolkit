################################################################################
# DDC Network Load Balancers (Conditional Creation)
################################################################################



# Shared NLB (always created - tightly coupled to our EKS infrastructure)
resource "aws_lb" "shared_nlb" {
  name_prefix        = var.project_prefix
  load_balancer_type = "network"
  internal           = !local.is_external_access
  subnets            = local.is_external_access ? var.public_subnets : var.private_subnets
  
  security_groups = concat(
    var.existing_security_groups,
    var.ddc_infra_config.additional_nlb_security_groups,
    local.is_external_access ? [aws_security_group.external_nlb_sg[0].id] : [aws_security_group.internal_nlb_sg[0].id]
  )

  enable_deletion_protection = false
  
  dynamic "access_logs" {
    for_each = var.enable_centralized_logging && local.logs_bucket_id != null ? [1] : []
    content {
      enabled = true
      bucket  = local.logs_bucket_id
      prefix  = "infrastructure/nlb"
    }
  }

  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-shared-nlb"
    Type   = "Network Load Balancer"
    Access = local.is_external_access ? "External" : "Internal"
    Region = var.region
  })
}

# Shared NLB Target Group (always created - points to our EKS cluster)
resource "aws_lb_target_group" "shared_nlb_tg" {
  name_prefix = "${var.project_prefix}-"
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health/live"  # DDC health endpoint for bring-your-own NLB
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-shared-nlb-tg"
    Region = var.region
  })
}

# Shared NLB HTTP Listener (Debug Mode Only)
resource "aws_lb_listener" "shared_nlb_http_listener" {
  count = var.debug_mode == "enabled" ? 1 : 0
  
  load_balancer_arn = aws_lb.shared_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shared_nlb_tg.arn
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-shared-nlb-http-listener"
    Region = var.region
    DebugMode = "true"
  })
}

# Shared NLB HTTPS Listener (always created)
resource "aws_lb_listener" "shared_nlb_https_listener" {
  load_balancer_arn = aws_lb.shared_nlb.arn
  port              = "443"
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.shared_nlb_tg.arn
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-shared-nlb-https-listener"
    Region = var.region
  })
}

################################################################################
# NLB Target Group Attachments
################################################################################

# Target registration handled by AWS Load Balancer Controller via TargetGroupBinding
# in ddc-services module - no manual EC2 instance registration needed



################################################################################
# S3 Bucket for NLB Access Logs (if needed)
################################################################################

################################################################################
# Centralized Logging S3 Bucket (DDC Module Standard)
################################################################################

# Single logging bucket for entire DDC module
resource "aws_s3_bucket" "ddc_logs" {
  count         = var.enable_centralized_logging ? 1 : 0
  bucket        = "${local.name_prefix}-logs-${random_string.logs_suffix[0].result}"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-logs"
    Type = "Centralized Logging"
    Region = var.region
  })
}

# S3 bucket policy for load balancer access logs
resource "aws_s3_bucket_policy" "ddc_logs_policy" {
  count  = var.enable_centralized_logging ? 1 : 0
  bucket = aws_s3_bucket.ddc_logs[0].id
  policy = data.aws_iam_policy_document.ddc_logs_policy[0].json
}

data "aws_iam_policy_document" "ddc_logs_policy" {
  count = var.enable_centralized_logging ? 1 : 0
  
  # Allow ELB service account to write access logs
  statement {
    sid    = "AllowELBAccessLogs"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.ddc_logs[0].arn}/*"]
  }
  
  # Allow AWS services to write logs (broad permissions for simplicity)
  statement {
    sid    = "AllowAWSServicesLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = [
        "logs.amazonaws.com",
        "vpc-flow-logs.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }
    actions = ["s3:PutObject", "s3:GetBucketAcl", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.ddc_logs[0].arn,
      "${aws_s3_bucket.ddc_logs[0].arn}/*"
    ]
  }
}

data "aws_elb_service_account" "main" {}

################################################################################
# CloudWatch Log Groups (Issue #726 Standard)
################################################################################

# DDC Application Logs
resource "aws_cloudwatch_log_group" "ddc_application" {
  count             = var.enable_centralized_logging ? 1 : 0
  name              = "${local.name_prefix}-${var.region}/application/ddc"
  retention_in_days = var.log_retention_by_category.application
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ddc-application-logs"
    LogType = "Application"
    Description = "DDC service application logs"
  })
}

# EKS Control Plane Logs
resource "aws_cloudwatch_log_group" "eks_control_plane" {
  count             = var.enable_centralized_logging ? 1 : 0
  name              = "${local.name_prefix}-${var.region}/infrastructure/eks"
  retention_in_days = var.log_retention_by_category.infrastructure
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-control-plane-logs"
    LogType = "Infrastructure"
    Description = "EKS control plane logs"
  })
}

# ScyllaDB Service Logs
resource "aws_cloudwatch_log_group" "scylla_service" {
  count             = var.enable_centralized_logging ? 1 : 0
  name              = "${local.name_prefix}-${var.region}/service/scylla"
  retention_in_days = var.log_retention_by_category.service
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-service-logs"
    LogType = "Service"
    Description = "ScyllaDB database logs"
  })
}

# NLB Access Logs (CloudWatch - for real-time monitoring)
resource "aws_cloudwatch_log_group" "nlb_access" {
  count             = var.enable_centralized_logging ? 1 : 0
  name              = "${local.name_prefix}-${var.region}/infrastructure/nlb"
  retention_in_days = var.log_retention_by_category.infrastructure
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-nlb-access-logs"
    LogType = "Infrastructure"
    Description = "Network Load Balancer access logs"
  })
}

# ALB Access Logs (future-ready - no cost when empty)
resource "aws_cloudwatch_log_group" "alb_access" {
  count             = var.enable_centralized_logging ? 1 : 0
  name              = "${local.name_prefix}-${var.region}/infrastructure/alb"
  retention_in_days = var.log_retention_by_category.infrastructure
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-alb-access-logs"
    LogType = "Infrastructure"
    Description = "Application Load Balancer access logs"
  })
}

resource "random_string" "logs_suffix" {
  count   = var.enable_centralized_logging ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

