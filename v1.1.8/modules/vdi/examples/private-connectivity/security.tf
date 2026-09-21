# Security group for VDI instances
resource "aws_security_group" "vdi_private_sg" {
  name_prefix = "${local.project_prefix}-vdi-"
  vpc_id      = aws_vpc.vdi_vpc.id
  description = "Security group for VDI workstations"

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-private-sg"
  })
}

# Allow DCV access from VPC CIDR (private access)
resource "aws_vpc_security_group_ingress_rule" "vdi_dcv" {
  security_group_id = aws_security_group.vdi_private_sg.id
  description       = "DCV access from VPC CIDR"
  ip_protocol       = "tcp"
  from_port         = 8443
  to_port           = 8443
  cidr_ipv4         = "10.0.0.0/16"
}

# Allow HTTPS access from VPC CIDR
resource "aws_vpc_security_group_ingress_rule" "vdi_https" {
  security_group_id = aws_security_group.vdi_private_sg.id
  description       = "HTTPS access from VPC CIDR"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "10.0.0.0/16"
}

# Allow RDP access from VPC CIDR
resource "aws_vpc_security_group_ingress_rule" "vdi_rdp" {
  security_group_id = aws_security_group.vdi_private_sg.id
  description       = "RDP access from VPC CIDR"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = "10.0.0.0/16"
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "vdi_all_outbound" {
  security_group_id = aws_security_group.vdi_private_sg.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
