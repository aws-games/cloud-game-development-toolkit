# Security group for the VDI instance
resource "aws_security_group" "vdi_sg" {
  name_prefix = "${var.project_prefix}-${var.name}-vdi-"
  vpc_id      = var.vpc_id
  description = "Security group for VDI instances"

  # RDP access from user public IP
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.user_public_ip.response_body)}/32"]
    description = "RDP access from user public IP"
  }

  # NICE DCV access (HTTPS) from user public IP
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.user_public_ip.response_body)}/32"]
    description = "NICE DCV HTTPS access from user public IP"
  }

  # NICE DCV access (UDP for QUIC protocol) from user public IP
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "udp"
    cidr_blocks = ["${chomp(data.http.user_public_ip.response_body)}/32"]
    description = "NICE DCV QUIC access from user public IP"
  }

  # Domain joining traffic (only added if directory_id is provided)
  dynamic "ingress" {
    for_each = local.enable_domain_join ? [
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

  # Dynamic RPC ports for AD (only if domain joining is enabled)
  dynamic "ingress" {
    for_each = local.enable_domain_join ? [1] : []

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

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-vdi-sg"
  })
}
