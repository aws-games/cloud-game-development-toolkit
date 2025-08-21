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

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-managed-ad"
  })
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
  name_prefix = "${local.name_prefix}-managed-ad-"
  vpc_id      = aws_vpc.vdi_vpc.id
  description = "Security group for Managed Microsoft AD with least privilege access"

  # DNS (TCP and UDP)
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "DNS TCP"
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "DNS UDP"
  }

  # Kerberos (TCP and UDP)
  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "Kerberos TCP"
  }

  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "Kerberos UDP"
  }

  # RPC Endpoint Mapper
  ingress {
    from_port   = 135
    to_port     = 135
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "RPC Endpoint Mapper"
  }

  # LDAP (TCP and UDP)
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "LDAP TCP"
  }

  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "LDAP UDP"
  }

  # SMB/CIFS
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "SMB/CIFS"
  }

  # Kerberos Password Change (TCP and UDP)
  ingress {
    from_port   = 464
    to_port     = 464
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "Kerberos Password Change TCP"
  }

  ingress {
    from_port   = 464
    to_port     = 464
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "Kerberos Password Change UDP"
  }

  # LDAPS (LDAP over SSL)
  ingress {
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "LDAPS"
  }

  # Global Catalog (TCP and UDP)
  ingress {
    from_port   = 3268
    to_port     = 3268
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "Global Catalog TCP"
  }

  ingress {
    from_port   = 3269
    to_port     = 3269
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "Global Catalog SSL"
  }

  # Dynamic RPC ports (required for AD replication and some operations)
  # Note: This is still a wide range but necessary for AD functionality
  ingress {
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    description = "Dynamic RPC ports for AD operations"
  }

  # All outbound traffic (AD needs to communicate outbound)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-managed-ad-sg"
  })
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
