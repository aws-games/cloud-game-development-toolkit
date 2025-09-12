# Security group for VDI instances
resource "aws_security_group" "vdi_sg" {
  name_prefix = "${local.project_prefix}-vdi-"
  vpc_id      = aws_vpc.vdi_vpc.id
  description = "Security group for VDI workstations"

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-sg"
  })
}

# Allow DCV access from current IP
resource "aws_vpc_security_group_ingress_rule" "vdi_dcv" {
  security_group_id = aws_security_group.vdi_sg.id
  description       = "DCV access from current IP"
  ip_protocol       = "tcp"
  from_port         = 8443
  to_port           = 8443
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow HTTP access from current IP (demonstration only - skip unless needed)
resource "aws_vpc_security_group_ingress_rule" "vdi_http" {
  security_group_id = aws_security_group.vdi_sg.id
  description       = "HTTP access from current IP (demo only)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow HTTPS access from current IP
resource "aws_vpc_security_group_ingress_rule" "vdi_https" {
  security_group_id = aws_security_group.vdi_sg.id
  description       = "HTTPS access from current IP"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow RDP access from current IP
resource "aws_vpc_security_group_ingress_rule" "vdi_rdp" {
  security_group_id = aws_security_group.vdi_sg.id
  description       = "RDP access from current IP"
  ip_protocol       = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "vdi_all_outbound" {
  security_group_id = aws_security_group.vdi_sg.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
