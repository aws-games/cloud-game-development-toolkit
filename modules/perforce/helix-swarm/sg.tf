# Security applied to Perforce Helix Swarm Instance
resource "aws_security_group" "swarm_instance_sg" {
  name        = "helix-swarm-sg"
  description = "SG for Helix Swarm instance."
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Security applied to Perforce Helix Swarm ALB
resource "aws_security_group" "swarm_alb_sg" {
  name        = "helix-swarm-alb-sg"
  description = "SG for Helix Swarm load balancer."
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Allow all outbound from Perforce Helix Swarm
resource "aws_vpc_security_group_egress_rule" "helix_swarm_outbound_internet" {
  security_group_id = aws_security_group.swarm_instance_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
  description       = "Helix Swarm out to Internet"
}

# Allow http access to Helix Swarm instance from ALB
resource "aws_vpc_security_group_ingress_rule" "helix_swarm_inbound_alb" {
  #checkov:skip=CKV_AWS_260:Resource does not explicitly provide access to open internet
  security_group_id            = aws_security_group.swarm_instance_sg.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
  referenced_security_group_id = aws_security_group.swarm_alb_sg.id
  description                  = "Helix Swarm in from ALB"
}

# Allow outbound http access from ALB to Swarm
resource "aws_vpc_security_group_egress_rule" "helix_swarm_alb_outbound_http" {
  security_group_id            = aws_security_group.swarm_alb_sg.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
  referenced_security_group_id = aws_security_group.swarm_instance_sg.id
  description                  = "ALB out to Helix Swarm"
}
