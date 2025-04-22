##########################################
# Perforce NLB Security Group
##########################################
resource "aws_security_group" "perforce_network_load_balancer" {
  name        = "${local.project_prefix}-perforce-nlb"
  description = "Perforce Network Load Balancer"
  vpc_id      = aws_vpc.perforce_vpc.id
  #checkov:skip=CKV2_AWS_5:Security group is attached to Perforce NLB

# Helix Swarm -> Helix Core
resource "aws_vpc_security_group_ingress_rule" "helix_core_inbound_swarm" {
  for_each = module.perforce_helix_core.security_group_ids
  security_group_id            = each.value
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
  description                  = "Enables Helix Swarm to access Helix Core ${each.key}."
}

# Helix Core -> Helix Swarm
resource "aws_vpc_security_group_ingress_rule" "helix_swarm_inbound_core" {
  for_each = module.perforce_helix_core.helix_core_eip_public_ips

  security_group_id = module.perforce_helix_swarm.alb_security_group_id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "${each.value}/32"
  description       = "Enables Helix Core ${each.key} to access Helix Swarm"
}

# Helix Core -> Helix Authentication Service
resource "aws_vpc_security_group_ingress_rule" "helix_auth_inbound_core" {
  for_each = module.perforce_helix_core.helix_core_eip_public_ips

  security_group_id = module.perforce_helix_authentication_service.alb_security_group_id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "${each.value}/32"
  description       = "Enables Helix Core ${each.key} to access Helix Authentication Service"

}

