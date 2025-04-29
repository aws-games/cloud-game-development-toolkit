##########################################
# Shared ECS Cluster for Services
##########################################

resource "aws_ecs_cluster" "perforce_cluster" {
  name = "perforce-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "providers" {
  cluster_name = aws_ecs_cluster.perforce_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

##########################################
# Perforce Helix Core
##########################################

module "perforce_helix_core" {
  source                = "../../helix-core"
  server_type           = "p4d_commit"
  instance_type         = "c8g.large"
  instance_architecture = "arm64"
  server_configuration = [
    {
    type = "commit"
    vpc_id                = aws_vpc.perforce_vpc.id
    subnet_id    = aws_subnet.public_subnets[0].id
    },
        {
    type = "replica"
    vpc_id                = aws_vpc.perforce_vpc.id
    subnet_id    = aws_subnet.private_subnets[0].id
    },
    {
    type = "edge"
    vpc_id                = aws_vpc.perforce_vpc.id
    subnet_id    = aws_subnet.private_subnets[0].id
    }
  ]

  # Networking
  vpc_id                      = aws_vpc.perforce_vpc.id
  instance_subnet_id          = aws_subnet.public_subnets[0].id
  internal                    = false # public
  fully_qualified_domain_name = "perforce.${var.root_domain_name}"
  helix_authentication_service_url = "https://auth.${aws_route53_zone.perforce_private_hosted_zone.name}"
  helix_core_super_user_password_secret_name = "example-password-secret-name"
  helix_core_super_user_username_secret_name = "example-username-secret-name"

}

##########################################
# Perforce Helix Authentication Service
##########################################

module "perforce_helix_authentication_service" {
  source = "../../helix-authentication-service"

  # Networking
  vpc_id                               = aws_vpc.perforce_vpc.id
  create_application_load_balancer     = false # Shared Perforce web services application load balancer
  helix_authentication_service_subnets = aws_subnet.private_subnets[*].id
  fully_qualified_domain_name          = "auth.perforce.${var.root_domain_name}"

  # Compute
  cluster_name = aws_ecs_cluster.perforce_cluster.name

  # Configuration
  enable_web_based_administration = true

  depends_on = [aws_ecs_cluster.perforce_cluster]
}

##########################################
# Perforce Helix Swarm
##########################################
module "perforce_helix_swarm" {
  source                      = "../../helix-swarm"
  vpc_id                      = aws_vpc.perforce_vpc.id
  cluster_name                = aws_ecs_cluster.perforce_cluster.name
  helix_swarm_alb_subnets     = aws_subnet.public_subnets[*].id
  helix_swarm_service_subnets = aws_subnet.private_subnets[*].id
  certificate_arn             = aws_acm_certificate.helix.arn
  p4d_port                    = "ssl:${aws_route53_record.perforce_helix_core_pvt[var.helix_core_server_type].name}:1666"
  create_application_load_balancer = false
  fully_qualified_domain_name      = "swarm.perforce.${var.root_domain_name}"
  cluster_name = aws_ecs_cluster.perforce_cluster.name
  # Configuration
  p4d_port                    = "ssl:${aws_route53_record.internal_helix_core.name}:1666"
  p4d_super_user_arn          = module.perforce_helix_core.helix_core_super_user_username_secret_arn
  p4d_super_user_password_arn = module.perforce_helix_core.helix_core_super_user_password_secret_arn
  p4d_swarm_user_arn          = module.perforce_helix_core.helix_core_super_user_username_secret_arn
  p4d_swarm_password_arn      = module.perforce_helix_core.helix_core_super_user_password_secret_arn
  enable_sso                  = true

  depends_on = [aws_ecs_cluster.perforce_cluster]
}

##########################################
# Perforce Network Load Balancer
##########################################
resource "aws_lb" "perforce" {
  name                             = "perforce"
  load_balancer_type               = "network"
  subnets                          = aws_subnet.public_subnets[*].id
  security_groups                  = [aws_security_group.perforce_network_load_balancer.id]
  drop_invalid_header_fields       = true
  enable_cross_zone_load_balancing = true
  #checkov:skip=CKV_AWS_91: Access logging not required for example deployment
  #checkov:skip=CKV_AWS_150: Load balancer deletion protection disabled for example deployment
}

###################################################
# Perforce Web Services Application Load Balancer
###################################################
resource "aws_lb" "perforce_web_services" {
  name                       = "perforce-web-services"
  load_balancer_type         = "application"
  subnets                    = aws_subnet.private_subnets[*].id
  internal                   = true
  security_groups            = [aws_security_group.perforce_web_services_alb.id]
  drop_invalid_header_fields = true
  #checkov:skip=CKV_AWS_91: Access logging not required for example deployment
  #checkov:skip=CKV_AWS_150: Load balancer deletion protection disabled for example deployment
}

##########################################
# Web Services Target Group
##########################################
resource "aws_lb_target_group" "perforce_web_services" {
  name        = "perforce-web-services"
  target_type = "alb"
  port        = 443
  protocol    = "TCP"
  vpc_id      = aws_vpc.perforce_vpc.id
}

resource "aws_lb_target_group_attachment" "perforce_web_services" {
  target_group_arn = aws_lb_target_group.perforce_web_services.arn
  target_id        = aws_lb.perforce_web_services.arn
  port             = 443
  depends_on       = [aws_lb_listener.perforce_web_services]
}

# Default rule redirects to Helix Swarm
resource "aws_lb_listener" "perforce_web_services" {
  load_balancer_arn = aws_lb.perforce_web_services.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.perforce.certificate_arn

  default_action {
    type = "redirect"
    redirect {
      host        = "swarm.perforce.${var.root_domain_name}"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Helix Swarm listener rule
resource "aws_lb_listener_rule" "perforce_helix_swarm" {
  listener_arn = aws_lb_listener.perforce_web_services.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = module.perforce_helix_swarm.target_group_arn
  }
  condition {
    host_header {
      values = ["swarm.perforce.${var.root_domain_name}"]
    }
  }
}

# Helix Authentication Service listener rule
resource "aws_lb_listener_rule" "perforce_helix_authentication_service" {
  listener_arn = aws_lb_listener.perforce_web_services.arn
  priority     = 200
  action {
    type             = "forward"
    target_group_arn = module.perforce_helix_authentication_service.target_group_arn
  }
  condition {
    host_header {
      values = ["auth.perforce.${var.root_domain_name}"]
    }
  }
}

##########################################
# Perforce Web Services Listener
##########################################
resource "aws_lb_listener" "perforce_web_services_alb" {
  load_balancer_arn = aws_lb.perforce.arn
  port              = 443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.perforce_web_services.arn
  }
}
