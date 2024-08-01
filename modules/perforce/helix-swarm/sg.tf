########################################
# SWARM SERVICE SECURITY GROUP
########################################

# swarm Service Security Group (attached to containers)
resource "aws_security_group" "helix_swarm_service_sg" {
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "Helix Swarm Service Security Group"
  tags        = local.tags
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "helix_swarm_service_outbound_ipv4" {
  security_group_id = aws_security_group.helix_swarm_service_sg.id
  description       = "Allow outbound traffic from Helix Swarm service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "helix_swarm_service_outbound_ipv6" {
  security_group_id = aws_security_group.helix_swarm_service_sg.id
  description       = "Allow outbound traffic from Helix Swarm service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Inbound access to Containers from ALB
resource "aws_vpc_security_group_ingress_rule" "helix_swarm_service_inbound_alb" {
  #checkov:skip=CKV_AWS_260: "This restricts inbound access on port 80 to the ALB."
  security_group_id            = aws_security_group.helix_swarm_service_sg.id
  description                  = "Allow inbound traffic from Helix Swarm ALB to Helix Swarm service"
  referenced_security_group_id = aws_security_group.helix_swarm_alb_sg.id
  from_port                    = var.helix_swarm_container_port
  to_port                      = var.helix_swarm_container_port
  ip_protocol                  = "tcp"
}

########################################
# SWARM LOAD BALANCER SECURITY GROUP
########################################

# swarm Load Balancer Security Group (attached to ALB)
resource "aws_security_group" "helix_swarm_alb_sg" {
  name        = "${local.name_prefix}-ALB"
  vpc_id      = var.vpc_id
  description = "Helix Swarm ALB Security Group"
  tags        = local.tags
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "helix_swarm_alb_outbound_service" {
  security_group_id            = aws_security_group.helix_swarm_alb_sg.id
  description                  = "Allow outbound traffic from Helix Swarm ALB to Helix Swarm service"
  referenced_security_group_id = aws_security_group.helix_swarm_service_sg.id
  from_port                    = var.helix_swarm_container_port
  to_port                      = var.helix_swarm_container_port
  ip_protocol                  = "tcp"
}


########################################
# SWARM FILE SYSTEM SECURITY GROUP
########################################

resource "aws_security_group" "helix_swarm_efs_security_group" {
  count       = var.enable_elastic_filesystem ? 1 : 0
  name        = "${local.name_prefix}-efs"
  vpc_id      = var.vpc_id
  description = "Helix Swarm EFS mount target Security Group"
  tags        = local.tags
}

# Inbound access from Service to EFS mount targets
resource "aws_vpc_security_group_ingress_rule" "helix_swarm_efs_inbound_service" {
  count                        = var.enable_elastic_filesystem ? 1 : 0
  security_group_id            = aws_security_group.helix_swarm_efs_security_group[0].id
  description                  = "Allow inbound access from Helix Swarm service containers to EFS."
  referenced_security_group_id = aws_security_group.helix_swarm_service_sg.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}
