##########################################
# Internal Access - service to service
##########################################

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
