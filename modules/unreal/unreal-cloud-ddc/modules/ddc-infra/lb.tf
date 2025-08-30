################################################################################
# DDC Network Load Balancer (Deterministic) - FIXES circular dependency
################################################################################

# This NLB is created by Terraform, not by AWS Load Balancer Controller
# This eliminates the circular dependency where applications module creates
# infrastructure that it then tries to reference
resource "aws_lb" "ddc_nlb" {
  name_prefix        = "${var.project_prefix}-"
  load_balancer_type = "network"
  subnets           = var.eks_node_group_subnets
  internal          = false
  
  security_groups = concat(
    var.existing_security_groups,
    var.additional_nlb_security_groups,
    [aws_security_group.ddc_nlb.id]
  )

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ddc-nlb"
    Type = "Network Load Balancer"
    Routability = "PUBLIC"
  })
}

# Dedicated security group for the NLB
resource "aws_security_group" "ddc_nlb" {
  name_prefix = "${local.name_prefix}-ddc-nlb-sg-"
  description = "DDC Network Load Balancer Security Group"
  vpc_id      = var.vpc_id

  # Allow HTTP traffic
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS traffic
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ddc-nlb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# NLB Target Group for DDC service
resource "aws_lb_target_group" "ddc_nlb_tg" {
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
  load_balancer_arn = aws_lb.ddc_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ddc_nlb_tg.arn
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ddc-nlb-listener"
  })
}