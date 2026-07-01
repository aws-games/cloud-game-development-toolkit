resource "aws_iam_instance_profile" "scylla_monitoring_profile" {
  count = var.create_scylla_monitoring_stack ? 1 : 0
  name  = "${local.name_prefix}-scylla-monitoring-profile"
  role  = aws_iam_role.scylla_monitoring_role[count.index].name
}

#Scylla monitoring instance
resource "aws_instance" "scylla_monitoring" {
  count                       = var.create_scylla_monitoring_stack ? 1 : 0
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.scylla_monitoring_instance_type
  subnet_id                   = element(var.scylla_subnets, count.index + 1)
  vpc_security_group_ids      = [aws_security_group.scylla_monitoring_sg[count.index].id]
  user_data                   = local.scylla_monitoring_user_data
  user_data_replace_on_change = true
  ebs_optimized               = true
  iam_instance_profile        = aws_iam_instance_profile.scylla_monitoring_profile[count.index].name
  monitoring                  = true
  root_block_device {
    volume_size = var.scylla_monitoring_instance_storage
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-monitoring"
    }
  )
}

########################################
# Scylla Monitoring Load Balancer
########################################

# Network Load Balancer for Scylla Monitoring
resource "aws_lb" "scylla_monitoring_alb" {
  count                            = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  name                             = "${var.project_prefix}-monitoring-alb"
  load_balancer_type               = "application"
  subnets                          = var.monitoring_application_load_balancer_subnets
  security_groups                  = concat([aws_security_group.scylla_monitoring_lb_sg[count.index].id], var.existing_security_groups)
  enable_cross_zone_load_balancing = true
  internal                         = var.internal_facing_application_load_balancer #set to false by default
  drop_invalid_header_fields       = true
  #checkov:skip=CKV2_AWS_20:Keeping for early development
  dynamic "access_logs" {
    for_each = var.enable_scylla_monitoring_lb_access_logs ? [1] : []
    content {
      enabled = var.enable_scylla_monitoring_lb_access_logs
      bucket  = var.scylla_monitoring_lb_access_logs_bucket != null ? var.scylla_monitoring_lb_access_logs_bucket : aws_s3_bucket.scylla_monitoring_lb_access_logs_bucket[0].id
      prefix  = var.scylla_monitoring_lb_access_logs_prefix != null ? var.scylla_monitoring_lb_access_logs_prefix : "${var.name}-alb"
    }
  }
  #checkov:skip=CKV2_AWS_28:Don't need WAF right now
  #checkov:skip=CKV_AWS_150:Deletion protection varibale default value false by default
  enable_deletion_protection = var.enable_scylla_monitoring_lb_deletion_protection
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-monitoring-alb"
    }
  )
}

resource "aws_lb_target_group" "scylla_monitoring_alb_target_group" {
  #checkov:skip=CKV_AWS_378: TLS termination at ALB
  count       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  name        = "${var.project_prefix}-scylla-monitoring-tg"
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
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-monitoring-tg"
    }
  )
}

# Listeners for Scylla Monitoring
resource "aws_lb_listener" "scylla_monitoring_listener" {
  count             = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.scylla_monitoring_alb[count.index].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_certificate_arn


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.scylla_monitoring_alb_target_group[count.index].arn
  }
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-monitoring-alb-listener"
    }
  )
}

# Attach the monitoring instance to the target group
resource "aws_lb_target_group_attachment" "scylla_monitoring" {
  count            = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  target_group_arn = aws_lb_target_group.scylla_monitoring_alb_target_group[count.index].arn
  target_id        = aws_instance.scylla_monitoring[0].id
  port             = 3000
}

data "aws_elb_service_account" "main" {}
