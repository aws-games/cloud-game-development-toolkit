########################################
# SWARM SERVICE SECURITY GROUP
########################################

# swarm Service Security Group (attached to containers)
resource "aws_security_group" "swarm_service_sg" {
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "swarm Service Security Group"
  tags        = local.tags
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "swarm_service_outbound_ipv4" {
  security_group_id = aws_security_group.swarm_service_sg.id
  description       = "Allow outbound traffic from swarm service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "swarm_service_outbound_ipv6" {
  security_group_id = aws_security_group.swarm_service_sg.id
  description       = "Allow outbound traffic from swarm service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Inbound access to Containers from ALB
resource "aws_vpc_security_group_ingress_rule" "swarm_service_inbound_alb" {
  #checkov:skip=CKV_AWS_260: "This restricts inbound access on port 80 to the ALB."
  security_group_id            = aws_security_group.swarm_service_sg.id
  description                  = "Allow inbound traffic from swarm ALB to service"
  referenced_security_group_id = aws_security_group.swarm_alb_sg.id
  from_port                    = var.swarm_container_port
  to_port                      = var.swarm_container_port
  ip_protocol                  = "tcp"
}

########################################
# SWARM LOAD BALANCER SECURITY GROUP
########################################

# swarm Load Balancer Security Group (attached to ALB)
resource "aws_security_group" "swarm_alb_sg" {
  name        = "${local.name_prefix}-ALB"
  vpc_id      = var.vpc_id
  description = "swarm ALB Security Group"
  tags        = local.tags
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "swarm_alb_outbound_service" {
  security_group_id            = aws_security_group.swarm_alb_sg.id
  description                  = "Allow outbound traffic from swarm ALB to swarm service"
  referenced_security_group_id = aws_security_group.swarm_service_sg.id
  from_port                    = var.swarm_container_port
  to_port                      = var.swarm_container_port
  ip_protocol                  = "tcp"
}


########################################
# SWARM FILE SYSTEM SECURITY GROUP
########################################

resource "aws_security_group" "swarm_efs_security_group" {
  count       = var.enable_elastic_filesystem ? 1 : 0
  name        = "${local.name_prefix}-efs"
  vpc_id      = var.vpc_id
  description = "swarm EFS mount target Security Group"
  tags        = local.tags
}

# Inbound access from Service to EFS mount targets
resource "aws_vpc_security_group_ingress_rule" "swarm_efs_inbound_service" {
  count                        = var.enable_elastic_filesystem ? 1 : 0
  security_group_id            = aws_security_group.swarm_efs_security_group[0].id
  description                  = "Allow inbound access from Helix Swarm service containers to EFS."
  referenced_security_group_id = aws_security_group.swarm_service_sg.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "swarm_elasticache_sg" {
  count       = var.enable_elasticache_serverless ? 1 : 0
  name        = "${local.name_prefix}-elasticache"
  vpc_id      = var.vpc_id
  description = "Swarm Elasticache security group"
  tags        = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "swarm_elasticache_inbound_service" {
  count                        = var.enable_elasticache_serverless ? 1 : 0
  security_group_id            = aws_security_group.swarm_elasticache_sg[0].id
  description                  = "Allow inbound access from Helix Swarm service to Elasticache."
  referenced_security_group_id = aws_security_group.swarm_service_sg.id
  from_port                    = 6379
  to_port                      = 6380
  ip_protocol                  = "tcp"
}
