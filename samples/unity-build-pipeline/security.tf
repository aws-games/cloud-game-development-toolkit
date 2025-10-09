##########################################
# Security Groups
##########################################

# Security group for allowing access from user's IP
resource "aws_security_group" "allow_my_ip" {
  name        = "${local.project_prefix}-allow-my-ip"
  description = "Allow inbound traffic from my IP"
  vpc_id      = aws_vpc.unity_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-allow-my-ip"
  })
}

# Allow HTTPS traffic from user's IP
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow HTTPS traffic from personal IP"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${local.my_ip}/32"
}

# Allow Perforce traffic from user's IP
resource "aws_vpc_security_group_ingress_rule" "allow_perforce" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow Perforce traffic from personal IP"
  from_port         = 1666
  to_port           = 1666
  ip_protocol       = "tcp"
  cidr_ipv4         = "${local.my_ip}/32"
}

# Allow Perforce traffic from VPC (includes TeamCity agents)
resource "aws_vpc_security_group_ingress_rule" "perforce_from_vpc" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow Perforce traffic from VPC (TeamCity agents)"
  from_port         = 1666
  to_port           = 1666
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc_cidr_block
}
