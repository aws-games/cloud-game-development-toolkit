########################################
# ALB Security Group
########################################
# Load Balancer Security Group (attached to ALB)
resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5: Attached to ALB on creation
  count       = var.create_application_load_balancer ? 1 : 0
  name        = "${local.name_prefix}-alb"
  vpc_id      = var.vpc_id
  description = "${local.name_prefix} ALB Security Group"
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "alb_outbound_to_ecs_service" {
  count                        = var.create_application_load_balancer ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  description                  = "Allow outbound traffic from ALB to ${local.name_prefix} ECS service"
  referenced_security_group_id = aws_security_group.ecs_service.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

########################################
# ECS Service Security Group
########################################
# Service Security Group (attached to containers)
resource "aws_security_group" "ecs_service" {
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "${local.name_prefix} service Security Group"
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-service"
    }
  )
}

# Inbound access to Containers from ALB
resource "aws_vpc_security_group_ingress_rule" "ecs_service_inbound_from_alb" {
  count                        = var.create_application_load_balancer ? 1 : 0
  security_group_id            = aws_security_group.ecs_service.id
  description                  = "Allow inbound traffic from ${local.name_prefix} ALB to ${local.name_prefix} service"
  referenced_security_group_id = aws_security_group.alb[0].id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "ecs_service_outbound_to_internet_ipv4" {
  security_group_id = aws_security_group.ecs_service.id
  description       = "Allow outbound traffic from ${local.name_prefix} service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "ecs_service_outbound_to_internet_ipv6" {
  security_group_id = aws_security_group.ecs_service.id
  description       = "Allow outbound traffic from ${local.name_prefix} service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
