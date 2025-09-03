# AWS Directory Service - Managed Microsoft AD Configuration
# This file handles the creation of Managed Microsoft AD for the VDI example

# Create Managed Microsoft AD Directory
resource "aws_directory_service_directory" "managed_ad" {
  name     = var.directory_name
  password = local.ad_admin_password
  edition  = var.directory_edition
  type     = "MicrosoftAD"

  vpc_settings {
    vpc_id     = aws_vpc.vdi_vpc.id
    subnet_ids = [aws_subnet.vdi_private_subnet[0].id, aws_subnet.vdi_private_subnet[1].id]
  }

  description = "Managed Microsoft AD for VDI workstation domain joining and user management"
}

# Create DHCP Options Set for the VPC to use the Managed AD DNS
resource "aws_vpc_dhcp_options" "managed_ad_dhcp" {
  domain_name_servers = aws_directory_service_directory.managed_ad.dns_ip_addresses
  domain_name         = var.directory_name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dhcp-options"
  })
}

# Associate DHCP Options with VPC
resource "aws_vpc_dhcp_options_association" "managed_ad_dhcp_association" {
  vpc_id          = aws_vpc.vdi_vpc.id
  dhcp_options_id = aws_vpc_dhcp_options.managed_ad_dhcp.id
}

# Security Group for Managed Microsoft AD (Least Privilege)
resource "aws_security_group" "managed_ad_sg" {
  # checkov:skip=CKV2_AWS_5:Security groups are attached to EC2 instances through launch template
  name_prefix = "${local.name_prefix}-managed-ad-"
  vpc_id      = aws_vpc.vdi_vpc.id
  description = "Security group for Managed Microsoft AD with least privilege access"
}

# DNS TCP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_dns_tcp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "DNS TCP"
}

# DNS UDP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_dns_udp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "DNS UDP"
}

# Kerberos TCP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_kerberos_tcp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 88
  to_port           = 88
  ip_protocol       = "tcp"
  description       = "Kerberos TCP"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-managed-ad-kerberos-tcp"
  })
}

# Kerberos UDP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_kerberos_udp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 88
  to_port           = 88
  ip_protocol       = "udp"
  description       = "Kerberos UDP"
}

# RPC Endpoint Mapper ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_rpc_endpoint" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 135
  to_port           = 135
  ip_protocol       = "tcp"
  description       = "RPC Endpoint Mapper"
}

# LDAP TCP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_ldap_tcp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 389
  to_port           = 389
  ip_protocol       = "tcp"
  description       = "LDAP TCP"
}

# LDAP UDP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_ldap_udp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 389
  to_port           = 389
  ip_protocol       = "udp"
  description       = "LDAP UDP"
}

# SMB/CIFS ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_smb" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 445
  to_port           = 445
  ip_protocol       = "tcp"
  description       = "SMB/CIFS"
}

# Kerberos Password Change TCP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_kerberos_pwd_tcp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 464
  to_port           = 464
  ip_protocol       = "tcp"
  description       = "Kerberos Password Change TCP"
}

# Kerberos Password Change UDP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_kerberos_pwd_udp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 464
  to_port           = 464
  ip_protocol       = "udp"
  description       = "Kerberos Password Change UDP"
}

# LDAPS ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_ldaps" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 636
  to_port           = 636
  ip_protocol       = "tcp"
  description       = "LDAPS"
}

# Global Catalog TCP ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_global_catalog_tcp" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 3268
  to_port           = 3268
  ip_protocol       = "tcp"
  description       = "Global Catalog TCP"
}

# Global Catalog SSL ingress rule
resource "aws_vpc_security_group_ingress_rule" "managed_ad_global_catalog_ssl" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 3269
  to_port           = 3269
  ip_protocol       = "tcp"
  description       = "Global Catalog SSL"
}

# Dynamic RPC ports ingress rule (required for AD replication and some operations)
resource "aws_vpc_security_group_ingress_rule" "managed_ad_dynamic_rpc" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = aws_vpc.vdi_vpc.cidr_block
  from_port         = 1024
  to_port           = 65535
  ip_protocol       = "tcp"
  description       = "Dynamic RPC ports for AD operations"
}

# All outbound traffic egress rule (AD needs to communicate outbound)
resource "aws_vpc_security_group_egress_rule" "managed_ad_all_outbound" {
  security_group_id = aws_security_group.managed_ad_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound traffic"
}

# Enable Directory Data Access for DS Data API using AWS CLI
resource "null_resource" "enable_ds_data_access" {
  triggers = {
    directory_id = aws_directory_service_directory.managed_ad.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Enabling DS Data access for directory ${aws_directory_service_directory.managed_ad.id}..."

      # Check if DS Data access is already enabled
      if aws ds describe-directory-data-access --directory-id "${aws_directory_service_directory.managed_ad.id}" --query 'DataAccessStatus' --output text 2>/dev/null | grep -q "Enabled"; then
        echo "✓ DS Data access is already enabled"
      else
        echo "Enabling DS Data access..."
        aws ds enable-directory-data-access --directory-id "${aws_directory_service_directory.managed_ad.id}"
        echo "✓ DS Data access enabled successfully"
      fi
    EOT
  }

  depends_on = [aws_directory_service_directory.managed_ad]
}
