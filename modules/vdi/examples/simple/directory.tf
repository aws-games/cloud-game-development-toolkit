# AWS Directory Service - Simple AD Configuration
# Simple AD is created by default (enable_simple_ad = true)

# Create Simple AD (enabled by default)
resource "aws_directory_service_directory" "simple_ad" {
  count    = var.enable_simple_ad ? 1 : 0
  name     = var.directory_name
  password = var.directory_admin_password
  size     = var.directory_size
  type     = "SimpleAD"

  vpc_settings {
    vpc_id     = aws_vpc.vdi_vpc.id
    subnet_ids = [aws_subnet.vdi_private_subnet[0].id, aws_subnet.vdi_private_subnet[1].id]
  }

  description = "Simple AD for VDI workstation domain joining"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-simple-ad"
  })
}

# Create DHCP Options Set for the VPC to use the Simple AD DNS
resource "aws_vpc_dhcp_options" "simple_ad_dhcp" {
  count               = var.enable_simple_ad ? 1 : 0
  domain_name_servers = aws_directory_service_directory.simple_ad[0].dns_ip_addresses
  domain_name         = var.directory_name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dhcp-options"
  })
}

# Associate DHCP Options with VPC
resource "aws_vpc_dhcp_options_association" "simple_ad_dhcp_association" {
  count           = var.enable_simple_ad ? 1 : 0
  vpc_id          = aws_vpc.vdi_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.simple_ad_dhcp[0].id
}

# Security Group for Simple AD
resource "aws_security_group" "simple_ad_sg" {
  count       = var.enable_simple_ad ? 1 : 0
  name_prefix = "${local.name_prefix}-simple-ad-"
  vpc_id      = aws_vpc.vdi_vpc.id
  description = "Security group for Simple AD"

  # Allow all traffic within VPC for AD communication
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "All TCP traffic within VPC"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "All UDP traffic within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-simple-ad-sg"
  })
}