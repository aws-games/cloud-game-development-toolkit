################################################################################
# DDC Network Load Balancer (Deterministic) - FIXES circular dependency
################################################################################

# This NLB is created by Terraform, not by AWS Load Balancer Controller
# This eliminates the circular dependency where applications module creates
# infrastructure that it then tries to reference
resource "aws_lb" "ddc_nlb" {
  count              = var.ddc_infra_config != null ? 1 : 0
  name_prefix        = "${var.project_prefix}-"
  load_balancer_type = "network"
  subnets           = var.ddc_infra_config.eks_node_group_subnets
  internal          = false
  
  security_groups = concat(
    var.existing_security_groups,
    var.ddc_infra_config.additional_nlb_security_groups,
    [aws_security_group.ddc_nlb[0].id]
  )

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ddc-nlb"
    Type = "Network Load Balancer"
    Routability = "PUBLIC"
  })
}

# NLB Target Group for DDC service
resource "aws_lb_target_group" "ddc_nlb_tg" {
  count       = var.ddc_infra_config != null ? 1 : 0
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
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ddc-nlb-tg"
  })
}

# NLB Listener
resource "aws_lb_listener" "ddc_nlb_listener" {
  count             = var.ddc_infra_config != null ? 1 : 0
  load_balancer_arn = aws_lb.ddc_nlb[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ddc_nlb_tg[0].arn
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ddc-nlb-listener"
  })
}

################################################################################
# DDC Monitoring Application Load Balancer
################################################################################

# Application Load Balancer for DDC Monitoring
resource "aws_lb" "ddc_monitoring_alb" {
  count                            = var.ddc_monitoring_config != null && var.ddc_monitoring_config.create_application_load_balancer ? 1 : 0
  name_prefix                      = "${var.project_prefix}-"
  load_balancer_type               = "application"
  subnets                          = var.ddc_monitoring_config.monitoring_application_load_balancer_subnets
  security_groups                  = concat(
    var.existing_security_groups,
    var.ddc_monitoring_config.additional_alb_security_groups,
    [aws_security_group.ddc_monitoring_alb[0].id]
  )
  enable_cross_zone_load_balancing = true
  internal                         = var.ddc_monitoring_config.internal_facing_application_load_balancer
  drop_invalid_header_fields       = true
  
  dynamic "access_logs" {
    for_each = var.ddc_monitoring_config.enable_scylla_monitoring_lb_access_logs ? [1] : []
    content {
      enabled = var.ddc_monitoring_config.enable_scylla_monitoring_lb_access_logs
      bucket  = var.ddc_monitoring_config.scylla_monitoring_lb_access_logs_bucket != null ? var.ddc_monitoring_config.scylla_monitoring_lb_access_logs_bucket : aws_s3_bucket.ddc_monitoring_lb_access_logs_bucket[0].id
      prefix  = var.ddc_monitoring_config.scylla_monitoring_lb_access_logs_prefix != null ? var.ddc_monitoring_config.scylla_monitoring_lb_access_logs_prefix : "${var.ddc_monitoring_config.name}-alb"
    }
  }
  
  enable_deletion_protection = var.ddc_monitoring_config.enable_scylla_monitoring_lb_deletion_protection
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-monitoring-alb"
    Type = "Application Load Balancer"
    Routability = var.ddc_monitoring_config.internal_facing_application_load_balancer ? "PRIVATE" : "PUBLIC"
  })
}

resource "aws_lb_target_group" "ddc_monitoring_alb_target_group" {
  count       = var.ddc_monitoring_config != null && var.ddc_monitoring_config.create_application_load_balancer ? 1 : 0
  name_prefix = "${var.project_prefix}-"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/api/health"
    port                = 3000
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-monitoring-tg"
    TrafficDestination = "${local.name_prefix}-monitoring-service"
  })
}

# Listeners for DDC Monitoring
resource "aws_lb_listener" "ddc_monitoring_listener" {
  count             = var.ddc_monitoring_config != null && var.ddc_monitoring_config.create_application_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.ddc_monitoring_alb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.ddc_monitoring_config.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ddc_monitoring_alb_target_group[0].arn
  }
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-monitoring-alb-listener"
    TrafficSource = "${local.name_prefix}-monitoring-alb"
    TrafficDestination = "${local.name_prefix}-monitoring-tg"
  })
}

################################################################################
# S3 Bucket for ALB Access Logs (if needed)
################################################################################

resource "aws_s3_bucket" "ddc_monitoring_lb_access_logs_bucket" {
  count         = var.ddc_monitoring_config != null && var.ddc_monitoring_config.enable_scylla_monitoring_lb_access_logs && var.ddc_monitoring_config.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  bucket        = "${var.project_prefix}-${var.ddc_monitoring_config.name}-monitoring-lb-logs-${random_string.monitoring_lb_logs_suffix[0].result}"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.ddc_monitoring_config.name}-monitoring-lb-logs"
  })
}

resource "random_string" "monitoring_lb_logs_suffix" {
  count   = var.ddc_monitoring_config != null && var.ddc_monitoring_config.enable_scylla_monitoring_lb_access_logs && var.ddc_monitoring_config.scylla_monitoring_lb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}