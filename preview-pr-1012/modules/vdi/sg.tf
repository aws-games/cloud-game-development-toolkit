
resource "aws_security_group" "workstation" {
  #checkov:skip=CKV2_AWS_5:Security group is attached to EC2 instances via workstation security_groups variable
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

resource "aws_vpc_security_group_ingress_rule" "rdp_access_additional" {
  for_each = var.create_default_security_groups ? {
    for user_cidr in flatten([
      for workstation_key, config in local.final_instances : [
        for idx, cidr in config.allowed_cidr_blocks : {
          workstation_key = workstation_key
          cidr            = cidr
          key             = "${workstation_key}-${idx}"
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

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  for_each = var.create_default_security_groups ? {
    for workstation_key, config in local.final_instances : workstation_key => config
  } : {}

  security_group_id = aws_security_group.workstation[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound traffic"
}
