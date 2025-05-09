# Load Balancer for TeamCity Service
resource "aws_lb" "teamcity_external_lb" {
  count              = var.create_external_alb ? 1 : 0
  name               = "${local.name_prefix}-lb"
  security_groups    = [aws_security_group.teamcity_alb_sg[0].id]
  load_balancer_type = "application"
  internal           = false
  subnets            = var.alb_subnets


  dynamic "access_logs" {
    for_each = var.enable_teamcity_alb_access_logs ? [1] : []
    content {
      enabled = var.enable_teamcity_alb_access_logs
      bucket  = var.teamcity_alb_access_logs_bucket != null ? var.teamcity_alb_access_logs_bucket : aws_s3_bucket.teamcity_alb_access_logs_bucket[0].id
      prefix  = var.teamcity_alb_access_logs_prefix != null ? var.teamcity_alb_access_logs_prefix : "${local.name_prefix}-alb"
    }
  }
  #checkov:skip=CKV_AWS_150:Deletion protection disabled by default
  enable_deletion_protection = var.enable_teamcity_alb_deletion_protection


  #checkov:skip=CKV2_AWS_28: ALB access is managed with SG allow listing

  drop_invalid_header_fields = true
  tags                       = local.tags
}

# TeamCity target group for ALB
resource "aws_lb_target_group" "teamcity_target_group" {
  #checkov:skip=CKV_AWS_378: Using ALB for TLS termination
  count       = var.create_external_alb ? 1 : 0
  name        = "${local.name_prefix}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthCheck/healthy"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    port                = var.container_port
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = local.tags
}

# ALB HTTPS Listener
resource "aws_lb_listener" "teamcity_listener" {
  count             = var.create_external_alb ? 1 : 0
  load_balancer_arn = aws_lb.teamcity_external_lb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.teamcity_target_group[0].arn
  }
  tags = local.tags
}