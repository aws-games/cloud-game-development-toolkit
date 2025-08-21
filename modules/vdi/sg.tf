# Default security groups for VDI instances (created when create_default_security_groups = true)
resource "aws_security_group" "vdi_default_sg" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.create_default_security_groups
  }

  name_prefix = "${var.project_prefix}-${each.key}-vdi-"
  vpc_id      = var.vpc_id
  description = "Default security group for VDI instance ${each.key}"

  # RDP access from user's public IP (if detected) and allowed CIDR blocks
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = local.user_public_ip_cidr != null ? concat([local.user_public_ip_cidr], each.value.allowed_cidr_blocks) : each.value.allowed_cidr_blocks
    description = local.user_public_ip_cidr != null ? "RDP access from user public IP ${local.user_public_ip_cidr} and allowed networks" : "RDP access from allowed networks"
  }

  # NICE DCV access (HTTPS) from user's public IP (if detected) and allowed CIDR blocks
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = local.user_public_ip_cidr != null ? concat([local.user_public_ip_cidr], each.value.allowed_cidr_blocks) : each.value.allowed_cidr_blocks
    description = local.user_public_ip_cidr != null ? "NICE DCV HTTPS access from user public IP ${local.user_public_ip_cidr} and allowed networks" : "NICE DCV HTTPS access from allowed networks"
  }

  # NICE DCV access (UDP for QUIC protocol) from user's public IP (if detected) and allowed CIDR blocks
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "udp"
    cidr_blocks = local.user_public_ip_cidr != null ? concat([local.user_public_ip_cidr], each.value.allowed_cidr_blocks) : each.value.allowed_cidr_blocks
    description = local.user_public_ip_cidr != null ? "NICE DCV QUIC access from user public IP ${local.user_public_ip_cidr} and allowed networks" : "NICE DCV QUIC access from allowed networks"
  }

  # HTTPS access (port 443) from user's public IP (if detected) and allowed CIDR blocks
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.user_public_ip_cidr != null ? concat([local.user_public_ip_cidr], each.value.allowed_cidr_blocks) : each.value.allowed_cidr_blocks
    description = local.user_public_ip_cidr != null ? "HTTPS access from user public IP ${local.user_public_ip_cidr} and allowed networks" : "HTTPS access from allowed networks"
  }

  # Domain joining traffic (only added if this user joins AD)
  dynamic "ingress" {
    for_each = each.value.join_ad ? [
      { port = 53, protocol = "tcp", description = "DNS TCP" },
      { port = 53, protocol = "udp", description = "DNS UDP" },
      { port = 88, protocol = "tcp", description = "Kerberos TCP" },
      { port = 88, protocol = "udp", description = "Kerberos UDP" },
      { port = 135, protocol = "tcp", description = "RPC Endpoint Mapper" },
      { port = 389, protocol = "tcp", description = "LDAP" },
      { port = 389, protocol = "udp", description = "LDAP UDP" },
      { port = 445, protocol = "tcp", description = "SMB" },
      { port = 464, protocol = "tcp", description = "Kerberos Password Change TCP" },
      { port = 464, protocol = "udp", description = "Kerberos Password Change UDP" },
      { port = 636, protocol = "tcp", description = "LDAPS" }
    ] : []

    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = [data.aws_vpc.selected.cidr_block]
      description = ingress.value.description
    }
  }

  # Dynamic RPC ports for AD (only if this user joins AD)
  dynamic "ingress" {
    for_each = each.value.join_ad ? [1] : []

    content {
      from_port   = 1024
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.selected.cidr_block]
      description = "Dynamic RPC for AD"
    }
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(each.value.tags, {
    Name = "${var.project_prefix}-${each.key}-vdi-sg"
  })
}
