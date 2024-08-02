##########################################
# Internet Access (restricted)
##########################################

# Jenkins
resource "aws_vpc_security_group_ingress_rule" "jenkins_access" {
  for_each          = toset(local.allowlist)
  security_group_id = module.jenkins.alb_security_group
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
  description       = "Allows internet access to Jenkins."
}

# Helix Core
resource "aws_vpc_security_group_ingress_rule" "helix_core_access" {
  for_each          = toset(local.allowlist)
  security_group_id = module.perforce_helix_core.security_group_id
  ip_protocol       = "TCP"
  from_port         = 8085
  to_port           = 8085
  cidr_ipv4         = each.value
  description       = "Allows internet access to Helix Core."
}

# Helix Swarm
resource "aws_vpc_security_group_ingress_rule" "helix_swarm_access" {
  for_each          = toset(local.allowlist)
  security_group_id = module.perforce_helix_swarm.alb_security_group_id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
  description       = "Allows internet access to Helix Swarm."
}

# Helix Authentication Service
resource "aws_vpc_security_group_ingress_rule" "helix_auth_access" {
  for_each          = toset(local.allowlist)
  security_group_id = module.perforce_helix_authentication_service.alb_security_group_id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
  description       = "Allows internet access to Helix Authentication Service."
}

##########################################
# Internal Access - service to service
##########################################

# Jenkins Build Agents -> Perforce Helix Core
resource "aws_vpc_security_group_ingress_rule" "helix_core_inbound_build_farm" {
  security_group_id            = module.perforce_helix_core.security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.jenkins.build_farm_security_group
  description                  = "Enables build farm to access Helix Core."
}

# Helix Swarm -> Helix Core
resource "aws_vpc_security_group_ingress_rule" "helix_core_inbound_swarm" {
  security_group_id            = module.perforce_helix_core.security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.perforce_helix_swarm.service_security_group_id
  description                  = "Enables Helix Swarm to access Helix Core."
}

# Helix Core -> Helix Swarm
resource "aws_vpc_security_group_ingress_rule" "helix_swarm_inbound_core" {
  security_group_id = module.perforce_helix_swarm.alb_security_group_id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "${module.perforce_helix_core.helix_core_eip_public_ip}/32"
  description       = "Enables Helix Core to access Helix Swarm"
}

# Helix Core -> Helix Authentication Service
resource "aws_vpc_security_group_ingress_rule" "helix_auth_inbound_core" {
  security_group_id = module.perforce_helix_authentication_service.alb_security_group_id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "${module.perforce_helix_core.helix_core_eip_public_ip}/32"
  description       = "Enables Helix Core to access Helix Authentication Service"
}
