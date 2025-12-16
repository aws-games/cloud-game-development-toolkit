
# Application Load Balancer for web services
resource "aws_lb" "web_alb" {
  # checkov:skip=CKV_AWS_150: Deletion protection unnecessary for NLB.
  # checkov:skip=CKV_AWS_91: Access logging out of scope.
  name                       = "build-pipeline-alb"
  internal                   = true
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.internal_shared_application_load_balancer.id]
  subnets                    = aws_subnet.private_subnets[*].id
  drop_invalid_header_fields = true
}

# HTTPS listener for the internal ALB
resource "aws_lb_listener" "internal_https" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.shared.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Please use a valid subdomain."
      status_code  = "200"
    }
  }
}

# Network Load Balancer for non-HTTP/HTTPS traffic
resource "aws_lb" "service_nlb" {
  # checkov:skip=CKV_AWS_91: Access logging out of scope.
  # checkov:skip=CKV_AWS_150: Deletion protection unnecessary for NLB.
  name                             = "build-pipeline-nlb"
  internal                         = false
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = true
  subnets                          = aws_subnet.public_subnets[*].id
  security_groups = [
    aws_security_group.public_network_load_balancer.id,
    aws_security_group.allow_my_ip.id # grants end user access
  ]
}

# TLS listener for the public NLB
resource "aws_lb_listener" "public_https" {
  load_balancer_arn = aws_lb.service_nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target.arn
  }
}

# Target group for the internal ALB
resource "aws_lb_target_group" "alb_target" {
  name        = "internal-alb-target"
  port        = 443
  protocol    = "TCP"
  vpc_id      = aws_vpc.build_pipeline_vpc.id
  target_type = "alb"

  health_check {
    path              = "/"
    enabled           = true
    healthy_threshold = 2
    interval          = 30
    port              = "traffic-port"
    protocol          = "HTTPS"
    timeout           = 10
  }

  depends_on = [aws_lb_listener.internal_https]
}

# Attach the internal ALB to the target group
resource "aws_lb_target_group_attachment" "alb_attachment" {
  target_group_arn = aws_lb_target_group.alb_target.arn
  target_id        = aws_lb.web_alb.arn
  port             = 443
}

resource "aws_lb_listener_rule" "jenkins" {
  listener_arn = aws_lb_listener.internal_https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = module.jenkins.service_target_group_arn
  }

  condition {
    host_header {
      values = [local.jenkins_fully_qualified_domain_name]
    }
  }
}

resource "aws_lb_listener_rule" "perforce_auth" {
  listener_arn = aws_lb_listener.internal_https.arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = module.terraform-aws-perforce.p4_auth_target_group_arn
  }

  condition {
    host_header {
      values = [local.p4_auth_fully_qualified_domain_name]
    }
  }
}

resource "aws_lb_listener_rule" "perforce_code_review" {
  listener_arn = aws_lb_listener.internal_https.arn
  priority     = 120

  action {
    type             = "forward"
    target_group_arn = module.terraform-aws-perforce.p4_code_review_target_group_arn
  }

  condition {
    host_header {
      values = [local.p4_code_review_fully_qualified_domain_name]
    }
  }
}
