################################################################################
# DDC Network Load Balancers (COMMENTED OUT - LoadBalancer service creates NLB)
################################################################################

# Manual NLB creation disabled - AWS Load Balancer Controller creates NLB automatically
# from LoadBalancer service type in ddc-app module

# # Network Load Balancer (conditional creation based on presence)
# resource "aws_lb" "nlb" {
#   count = var.load_balancers_config.nlb != null ? 1 : 0
#   name               = local.nlb_name
#   load_balancer_type = "network"
#   internal           = !var.load_balancers_config.nlb.internet_facing
#   subnets            = var.load_balancers_config.nlb.subnets
# 
#   security_groups = concat(
#     var.load_balancers_config.nlb.security_groups,
# 
#     var.ddc_infra_config != null ? [aws_security_group.nlb[0].id] : []
#   )
# 
#   enable_deletion_protection = false
# 
#   dynamic "access_logs" {
#     for_each = var.enable_centralized_logging && var.load_balancers_config.nlb != null ? [1] : []
#     content {
#       enabled = true
#       bucket  = local.logs_bucket_id
#       prefix  = "infrastructure/nlb"
#     }
#   }
# 
#   tags = merge(local.default_tags, {
#     Name   = local.nlb_name
#     Type   = "Network Load Balancer"
#     Access = var.load_balancers_config.nlb.internet_facing ? "Internet-facing" : "Internal"
#   })
# }
# 
# # NLB Target Group (conditional - points to our EKS cluster)
# resource "aws_lb_target_group" "nlb_target_group" {
#   count = var.load_balancers_config.nlb != null ? 1 : 0
# 
#   name        = "${local.name_prefix}-${local.name_suffix}"
#   port        = 80
#   protocol    = "TCP"
#   vpc_id      = var.vpc_id
#   target_type = "ip"
# 
#   health_check {
#     enabled             = true
#     healthy_threshold   = 2
#     interval            = 30
#     matcher             = "200"
#     path                = "/health/live" # DDC health endpoint for bring-your-own NLB
#     port                = "traffic-port"
#     protocol            = "HTTP"
#     timeout             = 5
#     unhealthy_threshold = 2
#   }
# 
#   tags = merge(local.default_tags, {
#     Name = "${local.name_prefix}-${local.name_suffix}"
#   })
# }
# 
# # NLB HTTP Listener (conditional - forwards or redirects based on certificate availability)
# resource "aws_lb_listener" "http" {
#   count = var.load_balancers_config.nlb != null ? 1 : 0
# 
#   load_balancer_arn = aws_lb.nlb[0].arn
#   port              = "80"
#   protocol          = "TCP"
# 
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.nlb_target_group[0].arn
#   }
# 
#   tags = merge(local.default_tags, {
#     Name = "${local.name_prefix}-nlb-http-listener"
#     Mode = var.debug_mode == "enabled" ? "Debug" : "Production"
#   })
# }
# 
# # NLB HTTPS Listener (conditional creation)
# resource "aws_lb_listener" "https" {
#   count = var.load_balancers_config.nlb != null && var.load_balancers_config.nlb.internet_facing ? 1 : 0
# 
#   load_balancer_arn = aws_lb.nlb[0].arn
#   port              = "443"
#   protocol          = "TLS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.certificate_arn
# 
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.nlb_target_group[0].arn
#   }
# 
#   tags = merge(local.default_tags, {
#     Name     = "${local.name_prefix}-nlb-https-listener"
#     Security = "HTTPS-first"
#   })
# }

################################################################################
# NLB Target Group Attachments
################################################################################

# Target registration handled by LoadBalancer service + AWS Load Balancer Controller
# No manual target group binding needed

# Security warnings removed - handled by LoadBalancer service annotations



################################################################################
# S3 Bucket for NLB Access Logs (if needed)
################################################################################

################################################################################
# Centralized Logging S3 Bucket (DDC Module Standard)
################################################################################

# Single logging bucket for entire DDC module
resource "aws_s3_bucket" "logs" {
  count         = var.enable_centralized_logging ? 1 : 0
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

data "aws_elb_service_account" "main" {}

################################################################################
# CloudWatch Log Groups - Single Log Group for All Logs
################################################################################

# Single log group for all DDC logs (Kubernetes, ScyllaDB, NLB, etc.)
resource "aws_cloudwatch_log_group" "logs" {
  count             = var.enable_centralized_logging ? 1 : 0
  name              = "${local.log_prefix}-${local.region}"
  retention_in_days = var.log_retention_days

  tags = merge(local.default_tags, {
    Name     = local.log_prefix
    Category = "centralized-logging"
    LogType  = "all"
    Module   = "unreal-cloud-ddc"
  })
}





