# Default security groups for VDI instances (created when create_default_security_groups = true)
resource "aws_security_group" "workstation" {
  for_each = var.create_default_security_groups ? {
    for workstation_key, config in local.final_instances : workstation_key => config
  } : {}

  name_prefix = "${var.project_prefix}-${each.key}-workstation-"
  vpc_id      = var.vpc_id
  description = "Default security group for VDI workstation ${each.key}"

  tags = merge(var.tags, {
    Name        = "${var.project_prefix}-${each.key}-workstation-sg"
    Workstation = each.key
    Purpose     = "VDI Workstation Security"
  })
}

# RDP access ingress rules
resource "aws_vpc_security_group_ingress_rule" "rdp_access" {
  for_each = var.create_default_security_groups ? {
    for workstation_key, config in local.final_instances : workstation_key => config
  } : {}

  security_group_id = aws_security_group.workstation[each.key].id
  cidr_ipv4         = each.value.allowed_cidr_blocks[0]
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  description       = "RDP access from allowed CIDR"
}

# Additional RDP access for allowed CIDR blocks
resource "aws_vpc_security_group_ingress_rule" "rdp_access_additional" {
  for_each = var.create_default_security_groups ? {
    for user_cidr in flatten([
      for workstation_key, config in local.final_instances : [
        for idx, cidr in config.allowed_cidr_blocks : {
          workstation_key = workstation_key
          cidr = cidr
          key  = "${workstation_key}-${idx}"
        } if idx > 0
      ]
    ]) : user_cidr.key => user_cidr
  } : {}

  security_group_id = aws_security_group.workstation[each.value.workstation_key].id
  cidr_ipv4         = each.value.cidr
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  description       = "RDP access from additional CIDR"
}

# NICE DCV HTTPS access ingress rules
resource "aws_vpc_security_group_ingress_rule" "dcv_https_access" {
  for_each = var.create_default_security_groups ? {
    for workstation_key, config in local.final_instances : workstation_key => config
  } : {}

  security_group_id = aws_security_group.workstation[each.key].id
  cidr_ipv4         = each.value.allowed_cidr_blocks[0]
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "tcp"
  description       = "NICE DCV HTTPS access from allowed CIDR"
}

# NICE DCV QUIC (UDP) access ingress rules
resource "aws_vpc_security_group_ingress_rule" "dcv_quic_access" {
  for_each = var.create_default_security_groups ? {
    for workstation_key, config in local.final_instances : workstation_key => config
  } : {}

  security_group_id = aws_security_group.workstation[each.key].id
  cidr_ipv4         = each.value.allowed_cidr_blocks[0]
  from_port         = 8443
  to_port           = 8443
  ip_protocol       = "udp"
  description       = "NICE DCV QUIC access from allowed CIDR"
}

# HTTPS access ingress rules
resource "aws_vpc_security_group_ingress_rule" "https_access" {
  for_each = var.create_default_security_groups ? {
    for workstation_key, config in local.final_instances : workstation_key => config
  } : {}

  security_group_id = aws_security_group.workstation[each.key].id
  cidr_ipv4         = each.value.allowed_cidr_blocks[0]
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS access from allowed CIDR"
}

# Domain joining traffic ingress rules (only added if instance joins AD)
resource "aws_vpc_security_group_ingress_rule" "ad_ports_access" {
  for_each = var.create_default_security_groups && var.enable_ad_integration ? {
    for rule in flatten([
      for workstation_key, config in local.final_instances : [
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
          workstation_key = workstation_key
          port        = port_config.port
          protocol    = port_config.protocol
          description = port_config.description
          key         = "${workstation_key}-${port_config.port}-${port_config.protocol}"
        }
      ]
    ]) : rule.key => rule
  } : {}

  security_group_id = aws_security_group.workstation[each.value.workstation_key].id
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = each.value.protocol
  description       = each.value.description
}

# Dynamic RPC ports for AD (only if instance joins AD)
resource "aws_vpc_security_group_ingress_rule" "ad_dynamic_rpc_access" {
  for_each = var.create_default_security_groups && var.enable_ad_integration ? {
    for workstation_key, config in local.final_instances : workstation_key => config
  } : {}

  security_group_id = aws_security_group.workstation[each.key].id
  cidr_ipv4         = data.aws_vpc.selected.cidr_block
  from_port         = 1024
  to_port           = 65535
  ip_protocol       = "tcp"
  description       = "Dynamic RPC for AD"
}

# All outbound traffic egress rules
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  for_each = var.create_default_security_groups ? {
    for workstation_key, config in local.final_instances : workstation_key => config
  } : {}

  security_group_id = aws_security_group.workstation[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound traffic"
}