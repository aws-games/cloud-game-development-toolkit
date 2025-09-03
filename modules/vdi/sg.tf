# Default security groups for VDI instances (created when create_default_security_groups = true)
resource "aws_security_group" "vdi_default_sg" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.create_default_security_groups
  }

  name_prefix = "${var.project_prefix}-${each.key}-vdi-"
  vpc_id      = var.vpc_id
  description = "Default security group for VDI instance ${each.key}"

  tags = merge(each.value.tags, {
    Name = "${var.project_prefix}-${each.key}-vdi-sg"
  })
}

# RDP access ingress rules
resource "aws_vpc_security_group_ingress_rule" "vdi_rdp" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.create_default_security_groups
  }

  security_group_id = aws_security_group.vdi_default_sg[each.key].id
  cidr_ipv4         = lookup(local.user_public_ips_cidr, each.key, each.value.allowed_cidr_blocks[0])
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  description       = "RDP access from user public IP"
}

# Additional RDP access for allowed CIDR blocks (when user public IP is detected)
resource "aws_vpc_security_group_ingress_rule" "vdi_rdp_additional" {
  for_each = {
    for user_cidr in flatten([
      for user, config in local.processed_vdi_config : [
        for idx, cidr in config.allowed_cidr_blocks : {
          user = user
          cidr = cidr
          key  = "${user}-${idx}"
        }
      ]
      if config.create_default_security_groups && contains(keys(var.user_public_ips), user)
    ]) : user_cidr.key => user_cidr
  }

  security_group_id = aws_security_group.vdi_default_sg[each.value.user].id
  cidr_ipv4         = each.value.cidr
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  description       = "RDP access from VPC"
}

# NICE DCV HTTPS access ingress rules
resource "aws_vpc_security_group_ingress_rule" "vdi_dcv_https" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.create_default_security_groups
  }

  security_group_id = aws_security_group.vdi_default_sg[each.key].id
  cidr_ipv4         = lookup(local.user_public_ips_cidr, each.key, each.value.allowed_cidr_blocks[0])
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "tcp"
  description       = "NICE DCV HTTPS access from user public IP"
}

# Additional NICE DCV HTTPS access for allowed CIDR blocks (when user public IP is detected)
resource "aws_vpc_security_group_ingress_rule" "vdi_dcv_https_additional" {
  for_each = {
    for user_cidr in flatten([
      for user, config in local.processed_vdi_config : [
        for idx, cidr in config.allowed_cidr_blocks : {
          user = user
          cidr = cidr
          key  = "${user}-${idx}"
        }
      ]
      if config.create_default_security_groups && contains(keys(var.user_public_ips), user)
    ]) : user_cidr.key => user_cidr
  }

  security_group_id = aws_security_group.vdi_default_sg[each.value.user].id
  cidr_ipv4         = each.value.cidr
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "tcp"
  description       = "NICE DCV HTTPS access from VPC"
}

# NICE DCV QUIC (UDP) access ingress rules
resource "aws_vpc_security_group_ingress_rule" "vdi_dcv_quic" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.create_default_security_groups
  }

  security_group_id = aws_security_group.vdi_default_sg[each.key].id
  cidr_ipv4         = lookup(local.user_public_ips_cidr, each.key, each.value.allowed_cidr_blocks[0])
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "udp"
  description       = "NICE DCV QUIC access from user public IP"
}

# Additional NICE DCV QUIC access for allowed CIDR blocks (when user public IP is detected)
resource "aws_vpc_security_group_ingress_rule" "vdi_dcv_quic_additional" {
  for_each = {
    for user_cidr in flatten([
      for user, config in local.processed_vdi_config : [
        for idx, cidr in config.allowed_cidr_blocks : {
          user = user
          cidr = cidr
          key  = "${user}-${idx}"
        }
      ]
      if config.create_default_security_groups && contains(keys(var.user_public_ips), user)
    ]) : user_cidr.key => user_cidr
  }

  security_group_id = aws_security_group.vdi_default_sg[each.value.user].id
  cidr_ipv4         = each.value.cidr
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "udp"
  description       = "NICE DCV QUIC access from VPC"
}

# HTTPS access ingress rules
resource "aws_vpc_security_group_ingress_rule" "vdi_https" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.create_default_security_groups
  }

  security_group_id = aws_security_group.vdi_default_sg[each.key].id
  cidr_ipv4         = lookup(local.user_public_ips_cidr, each.key, each.value.allowed_cidr_blocks[0])
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS access from user public IP"
}

# Additional HTTPS access for allowed CIDR blocks (when user public IP is detected)
resource "aws_vpc_security_group_ingress_rule" "vdi_https_additional" {
  for_each = {
    for user_cidr in flatten([
      for user, config in local.processed_vdi_config : [
        for idx, cidr in config.allowed_cidr_blocks : {
          user = user
          cidr = cidr
          key  = "${user}-${idx}"
        }
      ]
      if config.create_default_security_groups && contains(keys(var.user_public_ips), user)
    ]) : user_cidr.key => user_cidr
  }

  security_group_id = aws_security_group.vdi_default_sg[each.value.user].id
  cidr_ipv4         = each.value.cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS access from VPC"
}

# Domain joining traffic ingress rules (only added if user joins AD)
resource "aws_vpc_security_group_ingress_rule" "vdi_ad_ports" {
  for_each = {
    for rule in flatten([
      for user, config in local.processed_vdi_config : [
        for port_config in [
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
          ] : {
          user        = user
          port        = port_config.port
          protocol    = port_config.protocol
          description = port_config.description
          key         = "${user}-${port_config.port}-${port_config.protocol}"
        }
      ]
      if config.create_default_security_groups && config.join_ad
    ]) : rule.key => rule
  }

  security_group_id = aws_security_group.vdi_default_sg[each.value.user].id
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = each.value.protocol
  description       = each.value.description
}

# Dynamic RPC ports for AD (only if user joins AD)
resource "aws_vpc_security_group_ingress_rule" "vdi_ad_dynamic_rpc" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.create_default_security_groups && config.join_ad
  }

  security_group_id = aws_security_group.vdi_default_sg[each.key].id
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  from_port         = 1024
  to_port           = 65535
  ip_protocol       = "tcp"
  description       = "Dynamic RPC for AD"
}

# All outbound traffic egress rules
resource "aws_vpc_security_group_egress_rule" "vdi_all_outbound" {
  for_each = {
    for user, config in local.processed_vdi_config : user => config
    if config.create_default_security_groups
  }

  security_group_id = aws_security_group.vdi_default_sg[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound traffic"
}
