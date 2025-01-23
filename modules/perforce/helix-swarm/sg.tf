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
  count = var.create_application_load_balancer ? 1 : 0
  #checkov:skip=CKV_AWS_260: "This restricts inbound access on port 80 to the ALB."
  security_group_id            = aws_security_group.helix_swarm_service_sg.id
  description                  = "Allow inbound traffic from Helix Swarm ALB to Helix Swarm service"
  referenced_security_group_id = aws_security_group.helix_swarm_alb_sg[0].id
  from_port                    = var.helix_swarm_container_port
  to_port                      = var.helix_swarm_container_port
  ip_protocol                  = "tcp"
}

########################################
# SWARM LOAD BALANCER SECURITY GROUP
########################################

# swarm Load Balancer Security Group (attached to ALB)
resource "aws_security_group" "helix_swarm_alb_sg" {
  #checkov:skip=CKV2_AWS_5:Security group is attached to Application Load Balancer
  count       = var.create_application_load_balancer ? 1 : 0
  name        = "${local.name_prefix}-ALB"
  vpc_id      = var.vpc_id
  description = "Helix Swarm ALB Security Group"
  tags        = local.tags
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "helix_swarm_alb_outbound_service" {
  count                        = var.create_application_load_balancer ? 1 : 0
  security_group_id            = aws_security_group.helix_swarm_alb_sg[0].id
  description                  = "Allow outbound traffic from Helix Swarm ALB to Helix Swarm service"
  referenced_security_group_id = aws_security_group.helix_swarm_service_sg.id
  from_port                    = var.helix_swarm_container_port
  to_port                      = var.helix_swarm_container_port
  ip_protocol                  = "tcp"
}

# Helix Swarm Elasticache Redis Security Group
resource "aws_security_group" "helix_swarm_elasticache_sg" {
  count = var.existing_redis_connection != null ? 0 : 1
  #checkov:skip=CKV2_AWS_5:Security group is attached to Elasticache cluster
  name        = "${local.name_prefix}-elasticache"
  vpc_id      = var.vpc_id
  description = "Helix Swarm Elasticache Redis Security Group"
  tags        = local.tags
}
resource "aws_vpc_security_group_ingress_rule" "helix_swarm_elasticache_ingress" {
  count                        = var.existing_redis_connection != null ? 0 : 1
  security_group_id            = aws_security_group.helix_swarm_elasticache_sg[0].id
  description                  = "Allow inbound traffic from Helix Swarm service to Redis"
  referenced_security_group_id = aws_security_group.helix_swarm_service_sg.id
  from_port                    = local.elasticache_redis_port
  to_port                      = local.elasticache_redis_port
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "swarm_efs" {
  name        = "${local.name_prefix}-efs"
  vpc_id      = var.vpc_id
  description = "Helix Swarm EFS Security Group"
  tags        = local.tags
}

# Inbound access from Service to EFS mount targets
resource "aws_vpc_security_group_ingress_rule" "helix_swarm_efs_inbound_service" {
  security_group_id            = aws_security_group.swarm_efs.id
  description                  = "Allow inbound access from Helix Swarm service containers to EFS."
  referenced_security_group_id = aws_security_group.helix_swarm_service_sg.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}
