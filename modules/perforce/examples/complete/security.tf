##########################################
# Perforce NLB Security Group
##########################################
resource "aws_security_group" "perforce_network_load_balancer" {
  name        = "${local.project_prefix}-perforce-nlb"
  description = "Perforce Network Load Balancer"
  vpc_id      = aws_vpc.perforce_vpc.id
  #checkov:skip=CKV2_AWS_5:Security group is attached to Perforce NLB

  tags = {
    Name = "${local.project_prefix}-perforce-nlb"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Egress for Perforce NLB to Helix Core instance
resource "aws_vpc_security_group_egress_rule" "perforce_nlb_outbound_helix_core" {
  security_group_id            = aws_security_group.perforce_network_load_balancer.id
  description                  = "Perforce NLB outbound to Helix Core"
  from_port                    = 1666
  to_port                      = 1666
  ip_protocol                  = "TCP"
  referenced_security_group_id = module.perforce_helix_core.security_group_id
}

# Ingress from Perforce NLB to Helix Core instance
resource "aws_vpc_security_group_ingress_rule" "perforce_nlb_inbound_helix_core" {
  security_group_id            = module.perforce_helix_core.security_group_id
  description                  = "Perforce NLB inbound to Helix Core"
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = aws_security_group.perforce_network_load_balancer.id
}

# Egress for Perforce NLB to Perforce Web Services ALB
resource "aws_vpc_security_group_egress_rule" "perforce_nlb_outbound_web_alb" {
  security_group_id            = aws_security_group.perforce_network_load_balancer.id
  description                  = "Perforce NLB outbound to Web ALB"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "TCP"
  referenced_security_group_id = aws_security_group.perforce_web_services_alb.id
}

##########################################
# Perforce Web Services ALB Security Group
##########################################
resource "aws_security_group" "perforce_web_services_alb" {
  name        = "${local.project_prefix}-perforce-web-services-alb"
  description = "Perforce Web Services ALB"
  vpc_id      = aws_vpc.perforce_vpc.id
  #checkov:skip=CKV2_AWS_5:Security group is attached to Perforce Web Services ALB

  tags = {
    Name = "${local.project_prefix}-perforce-web-services-alb"
  }
  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS Ingress from Perforce NLB to Perforce Web Services ALB
resource "aws_vpc_security_group_ingress_rule" "perforce_nlb_inbound_web_alb_https" {
  security_group_id            = aws_security_group.perforce_web_services_alb.id
  description                  = "Perforce NLB inbound HTTPS to Web ALB"
  ip_protocol                  = "TCP"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.perforce_network_load_balancer.id
}

# HTTPS Ingress from Helix Core server (needed for Helix Authentication Service extension)
resource "aws_vpc_security_group_ingress_rule" "perforce_helix_core_inbound_web_alb_https" {
  security_group_id            = aws_security_group.perforce_web_services_alb.id
  description                  = "Helix Core inbound HTTPS to Web ALB"
  ip_protocol                  = "TCP"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = module.perforce_helix_core.security_group_id
}

# Egress for Perforce Web Services ALB to Helix Swarm service
resource "aws_vpc_security_group_egress_rule" "perforce_alb_outbound_helix_swarm" {
  security_group_id            = aws_security_group.perforce_web_services_alb.id
  description                  = "Perforce ALB outbound to Helix Swarm"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "TCP"
  referenced_security_group_id = module.perforce_helix_swarm.service_security_group_id
}

# Ingress from Perforce Web Services ALB to Helix Swarm service
resource "aws_vpc_security_group_ingress_rule" "perforce_alb_inbound_helix_swarm" {
  security_group_id            = module.perforce_helix_swarm.service_security_group_id
  description                  = "Perforce ALB inbound to Helix Swarm"
  ip_protocol                  = "TCP"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.perforce_web_services_alb.id
  #checkov:skip=CKV_AWS_260:Access restricted to Perforce Web Services ALB
}

# Egress for Perforce Web Services ALB to Helix Authentication service
resource "aws_vpc_security_group_egress_rule" "perforce_alb_outbound_helix_auth" {
  security_group_id            = aws_security_group.perforce_web_services_alb.id
  description                  = "Perforce ALB outbound to Helix Auth"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "TCP"
  referenced_security_group_id = module.perforce_helix_authentication_service.service_security_group_id
}

# Ingress from Perforce Web Services ALB to Helix Authentication service
resource "aws_vpc_security_group_ingress_rule" "perforce_alb_inbound_helix_auth" {
  security_group_id            = module.perforce_helix_authentication_service.service_security_group_id
  description                  = "Perforce ALB inbound to Helix Auth"
  ip_protocol                  = "TCP"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.perforce_web_services_alb.id
}

##########################################
# Helix Swarm to Helix Core
##########################################
resource "aws_vpc_security_group_ingress_rule" "perforce_helix_core_inbound_helix_swarm" {
  security_group_id            = module.perforce_helix_core.security_group_id
  description                  = "Helix Core inbound to Helix Swarm"
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.perforce_helix_swarm.service_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "perforce_helix_swarm_outbound_helix_core" {
  security_group_id            = module.perforce_helix_swarm.service_security_group_id
  description                  = "Helix Swarm outbound to Helix Core"
  from_port                    = 1666
  to_port                      = 1666
  ip_protocol                  = "TCP"
  referenced_security_group_id = module.perforce_helix_core.security_group_id
}
