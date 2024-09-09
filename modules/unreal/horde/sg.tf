
resource "aws_security_group" "unreal_horde_alb_sg" {
  name        = "${local.name_prefix}-ALB"
  vpc_id      = var.vpc_id
  description = "unreal_horde ALB Security Group"
  tags        = local.tags
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "unreal_horde_alb_outbound_service" {
  security_group_id            = aws_security_group.unreal_horde_alb_sg.id
  description                  = "Allow outbound traffic from unreal_horde ALB to unreal_horde service"
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "unreal_horde_alb_outbound_service_grpc" {
  security_group_id            = aws_security_group.unreal_horde_alb_sg.id
  description                  = "Allow outbound GRPC traffic from unreal_horde ALB to unreal_horde service"
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = 5002
  to_port                      = 5002
  ip_protocol                  = "tcp"
}

########################################
# unreal_horde SERVICE SECURITY GROUP
########################################

# unreal_horde Service Security Group (attached to containers)
resource "aws_security_group" "unreal_horde_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to Horde service
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "unreal_horde Service Security Group"
  tags        = local.tags
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "unreal_horde_outbound_ipv4" {
  security_group_id = aws_security_group.unreal_horde_sg.id
  description       = "Allow outbound traffic from unreal_horde service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "unreal_horde_outbound_ipv6" {
  security_group_id = aws_security_group.unreal_horde_sg.id
  description       = "Allow outbound traffic from unreal_horde service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Inbound access to Containers from ALB
resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_alb" {
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound traffic from unreal_horde ALB to service"
  referenced_security_group_id = aws_security_group.unreal_horde_alb_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_alb_grpc" {
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound GRPC traffic from unreal_horde ALB to service"
  referenced_security_group_id = aws_security_group.unreal_horde_alb_sg.id
  from_port                    = 5002
  to_port                      = 5002
  ip_protocol                  = "tcp"
}

# unreal_horde Elasticache Redis Security Group
resource "aws_security_group" "unreal_horde_elasticache_sg" {
  #checkov:skip=CKV2_AWS_5:Security group is attached to Elasticache cluster
  name        = "${local.name_prefix}-elasticache"
  vpc_id      = var.vpc_id
  description = "unreal_horde Elasticache Redis Security Group"
  tags        = local.tags
}
resource "aws_vpc_security_group_ingress_rule" "unreal_horde_elasticache_ingress" {
  security_group_id            = aws_security_group.unreal_horde_elasticache_sg.id
  description                  = "Allow inbound traffic from unreal_horde service to Redis"
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}

# unreal_horde DocumentDB Cluster Security Group
resource "aws_security_group" "unreal_horde_docdb_sg" {
  name        = "${local.name_prefix}-docdb"
  vpc_id      = var.vpc_id
  description = "unreal_horde DocumentDB Cluster Security Group"
  tags        = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "unreal_horde_docdb_ingress" {
  security_group_id            = aws_security_group.unreal_horde_docdb_sg.id
  description                  = "Allow inbound traffic from unreal_horde service to DocumentDB"
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
}
