########################################
# ECS Service Security Group
########################################
resource "aws_security_group" "ecs_service" {
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "${local.name_prefix} service Security Group"
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-service"
  })
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
