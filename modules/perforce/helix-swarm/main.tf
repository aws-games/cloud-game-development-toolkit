################################################################################
# Instance
################################################################################
resource "aws_instance" "helix_swarm_instance" {
  ami           = data.aws_ami.helix_swarm_ami.id
  instance_type = var.instance_type


  availability_zone = local.helix_swarm_az
  subnet_id         = var.instance_subnet_id

  iam_instance_profile = aws_iam_instance_profile.helix_swarm_instance_profile.id

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring    = true
  ebs_optimized = true

  root_block_device {
    encrypted = true
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-primary"
  })
}

################################################################################
# Load Balancer
################################################################################
resource "aws_lb" "swarm_alb" {
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  subnets            = var.swarm_alb_subnets
  security_groups    = var.existing_security_groups != null ? var.existing_security_groups : [aws_security_group.swarm_alb_sg.id]

  dynamic "access_logs" {
    for_each = var.enable_swarm_alb_access_logs ? [1] : []
    content {
      enabled = var.enable_swarm_alb_access_logs
      bucket  = var.swarm_alb_access_logs_bucket != null ? var.swarm_alb_access_logs_bucket : aws_s3_bucket.swarm_alb_access_logs_bucket[0].id
      prefix  = var.swarm_alb_access_logs_prefix != null ? var.swarm_alb_access_logs_prefix : "${local.name_prefix}-alb"
    }
  }

  enable_deletion_protection = var.enable_swarm_alb_deletion_protection

  drop_invalid_header_fields = true

  tags = local.tags
}

resource "random_string" "swarm_alb_access_logs_bucket_suffix" {
  count   = var.enable_swarm_alb_access_logs && var.swarm_alb_access_logs_bucket == null ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "swarm_alb_access_logs_bucket" {
  count  = var.enable_swarm_alb_access_logs && var.swarm_alb_access_logs_bucket == null ? 1 : 0
  bucket = "${local.name_prefix}-alb-access-logs-${random_string.swarm_alb_access_logs_bucket_suffix[0].result}"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-access-logs-${random_string.swarm_alb_access_logs_bucket_suffix[0].result}"
  })
}

resource "aws_lb_target_group" "swarm_alb_target_group" {
  name        = "${local.name_prefix}-tg"
  port        = local.swarm_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
  }
  tags = local.tags
}

# Attach Helix Swarm instance to target group
resource "aws_lb_target_group_attachment" "swarm_alb_target_group_attachment" {
  target_group_arn = aws_lb_target_group.swarm_alb_target_group.arn
  target_id        = aws_instance.helix_swarm_instance.id
  port             = local.swarm_port
}

# HTTPS listener for swarm ALB
resource "aws_lb_listener" "swarm_alb_https_listener" {
  load_balancer_arn = aws_lb.swarm_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.swarm_alb_target_group.arn
    type             = "forward"
  }

  tags = local.tags
}
