##########################################
# Perforce Helix Core Super User
##########################################

resource "awscc_secretsmanager_secret" "helix_core_super_user_password" {
  count       = var.helix_core_super_user_password_secret_arn == null ? 1 : 0
  name        = var.helix_core_super_user_password_secret_name
  description = "The password for the created Helix Core super user."
  generate_secret_string = {
    exclude_numbers     = false
    exclude_punctuation = true
    include_space       = false
  }
}

resource "awscc_secretsmanager_secret" "helix_core_super_user_username" {
  count         = var.helix_core_super_user_username_secret_arn == null ? 1 : 0
  name          = var.helix_core_super_user_username_secret_name
  secret_string = "perforce"
}


##########################################
# Perforce Helix Core Instance
##########################################

resource "aws_instance" "helix_core_instance" {
  for_each = { for idx, server in var.server_configuration : server.type => server}

  ami           = data.aws_ami.helix_core_ami.id
  instance_type = var.instance_type

  #availability_zone = local.helix_core_az
  subnet_id         = each.value.subnet_id

  iam_instance_profile = aws_iam_instance_profile.helix_core_instance_profile.id

 # user_data = <<-EOT
 #   #!/bin/bash
 #   /home/ec2-user/gpic_scripts/p4_configure.sh --hx_logs /dev/sdf --hx_metadata /dev/sdg --hx_depots /dev/sdh \
 #    --p4d_type ${var.server_type} \
 #    --username ${var.helix_core_super_user_username_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_username[0].secret_id : var.helix_core_super_user_username_secret_arn} \
 #    --password ${var.helix_core_super_user_password_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_password[0].secret_id : var.helix_core_super_user_password_secret_arn} \
 #    ${var.fully_qualified_domain_name == null ? "" : "--fqdn ${var.fully_qualified_domain_name}"} \
 #    ${var.helix_authentication_service_url == null ? "" : "--auth ${var.helix_authentication_service_url}"} \
 #    --case_sensitive ${var.helix_case_sensitive ? 1 : 0} \
 #    --unicode ${var.unicode ? "true" : "false"}
 # EOT


 # vpc_security_group_ids = var.create_default_sg ? concat(var.existing_security_groups, [aws_security_group.helix_core_security_group[0].id]) : var.existing_security_groups
  vpc_security_group_ids = [aws_security_group.helix_core_security_group[each.key].id]


  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring    = true
  ebs_optimized = true

  root_block_device {
    encrypted = true
  }

  tags = merge(local.tags, {
    #Name = "${local.name_prefix}-${var.server_type}-${local.helix_core_az}"
    Name = "${local.name_prefix}-${each.key}"
  },
  local.p4_server_type_tags[each.key]
  )
}

##########################################
# EIP For Internet Access to Instance
##########################################

resource "aws_eip" "helix_core_eip" {
  for_each = { for idx, server in var.server_configuration : server.type => server if !var.internal }
  #count    = var.internal ? 0 : 1
  instance = aws_instance.helix_core_instance[each.key].id
  domain   = "vpc"
}

##########################################
# Storage Configuration
##########################################

// hxlogs
resource "aws_ebs_volume" "logs" {
  for_each = {for idx, server in var.server_configuration : server.type => server }
  availability_zone = data.aws_subnet.selected[each.key].availability_zone
  size              = var.logs_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags              = merge(local.tags, { Name = "${local.name_prefix}-${each.key}-logs" })
}

resource "aws_volume_attachment" "logs_attachment" {
  for_each = { for idx, server in var.server_configuration : server.type => server }
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.logs[each.key].id
  instance_id = aws_instance.helix_core_instance[each.key].id
}

// hxmetadata
resource "aws_ebs_volume" "metadata" {
  for_each = { for idx, server in var.server_configuration : server.type => server }
  availability_zone = data.aws_subnet.selected[each.key].availability_zone
  size              = var.metadata_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags              = merge(local.tags, { Name = "${local.name_prefix}-${each.key}-logs" })
}

resource "aws_volume_attachment" "metadata_attachment" {
  for_each = { for idx, server in var.server_configuration : server.type => server }
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.metadata[each.key].id
  instance_id = aws_instance.helix_core_instance[each.key].id
}

// hxdepot
resource "aws_ebs_volume" "depot" {
  for_each = { for idx, server in var.server_configuration : server.type => server }
  availability_zone = data.aws_subnet.selected[each.key].availability_zone
  size              = var.depot_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags              = merge(local.tags, { Name = "${local.name_prefix}-${each.key}-logs" })
}

resource "aws_volume_attachment" "depot_attachment" {
  for_each = { for idx, server in var.server_configuration : server.type => server }
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.depot[each.key].id
  instance_id = aws_instance.helix_core_instance[each.key].id
}

##########################################
# Default SG for Internet Egress
##########################################

resource "aws_security_group" "helix_core_security_group" {
  for_each = { for idx, server in var.server_configuration : server.type => server}
  #count = var.create_default_sg ? 1 : 0
  #checkov:skip=CKV2_AWS_5:SG is attahced to FSxZ file systems

  vpc_id      = each.value.vpc_id
  name        = "${local.name_prefix}-${each.key}-instance"
  description = "Security group for Helix Core ${each.key} machine."
  tags        = local.tags
}

resource "aws_vpc_security_group_egress_rule" "helix_core_internet" {
  for_each = {for idx, server in var.server_configuration : server.type => server}
  #count             = var.create_default_sg ? 1 : 0
  security_group_id = aws_security_group.helix_core_security_group[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
  description       = "Helix Core out to Internet"
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inter_server_rpc" {
  for_each = merge([
    for server_type, server_ip in local.server_cidrs : {
      for target_type, target_ip in local.server_cidrs : 
      "${server_type}_from_${target_type}" => {
        sg_id = aws_security_group.helix_core_security_group[server_type].id
        cidr  = target_ip
      } if server_type != target_type
    }
  ]...)

  security_group_id = each.value.sg_id
  cidr_ipv4        = each.value.cidr
  from_port        = 111
  to_port          = 111
  ip_protocol      = "tcp"
  description      = "Allow RPC from ${split("_from_", each.key)[1]}"
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inter_server_1666" {
  for_each = merge([
    for server_type, server_ip in local.server_cidrs : {
      for target_type, target_ip in local.server_cidrs : 
      "${server_type}_from_${target_type}" => {
        sg_id = aws_security_group.helix_core_security_group[server_type].id
        cidr  = target_ip
      } if server_type != target_type
    }
  ]...)

  security_group_id = each.value.sg_id
  cidr_ipv4        = each.value.cidr
  from_port        = 1666
  to_port          = 1669
  ip_protocol      = "tcp"
  description      = "Allow Perforce traffic from ${split("_from_", each.key)[1]}"
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inter_server_nfs" {
  for_each = merge([
    for server_type, server_ip in local.server_cidrs : {
      for target_type, target_ip in local.server_cidrs : 
      "${server_type}_from_${target_type}" => {
        sg_id = aws_security_group.helix_core_security_group[server_type].id
        cidr  = target_ip
      } if server_type != target_type
    }
  ]...)

  security_group_id = each.value.sg_id
  cidr_ipv4        = each.value.cidr
  from_port        = 2049
  to_port          = 2049
  ip_protocol      = "tcp"
  description      = "Allow NFS from ${split("_from_", each.key)[1]}"
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inter_server_mountd" {
  for_each = merge([
    for server_type, server_ip in local.server_cidrs : {
      for target_type, target_ip in local.server_cidrs : 
      "${server_type}_from_${target_type}" => {
        sg_id = aws_security_group.helix_core_security_group[server_type].id
        cidr  = target_ip
      } if server_type != target_type
    }
  ]...)

  security_group_id = each.value.sg_id
  cidr_ipv4        = each.value.cidr
  from_port        = 20048
  to_port          = 20048
  ip_protocol      = "tcp"
  description      = "Allow mountd from ${split("_from_", each.key)[1]}"
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inter_server_8080" {
  for_each = merge([
    for server_type, server_ip in local.server_cidrs : {
      for target_type, target_ip in local.server_cidrs : 
      "${server_type}_from_${target_type}" => {
        sg_id = aws_security_group.helix_core_security_group[server_type].id
        cidr  = target_ip
      } if server_type != target_type
    }
  ]...)

  security_group_id = each.value.sg_id
  cidr_ipv4        = each.value.cidr
  from_port        = 8080
  to_port          = 8080
  ip_protocol      = "tcp"
  description      = "Allow port 8080 traffic from ${split("_from_", each.key)[1]}"
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inter_server_icmp" {
  for_each = merge([
    for server_type, server_ip in local.server_cidrs : {
      for target_type, target_ip in local.server_cidrs : 
      "${server_type}_from_${target_type}" => {
        sg_id = aws_security_group.helix_core_security_group[server_type].id
        cidr  = target_ip
      } if server_type != target_type
    }
  ]...)

  security_group_id = each.value.sg_id
  cidr_ipv4        = each.value.cidr
  from_port        = 8
  to_port          = 0
  ip_protocol      = "icmp"
  description      = "Allow ICMP from ${split("_from_", each.key)[1]}"
}


##########################################
# Systems Manager Parameter Store - Add facts about Helix Core servers
##########################################

resource "aws_ssm_parameter" "server_info" {
  for_each = { for idx, server in var.server_configuration : server.type => server }
  name  = "/perforce/${each.key}/server_info"
  type  = "StringList"
  value = "${aws_instance.helix_core_instance[each.key].private_ip},${aws_instance.helix_core_instance[each.key].private_dns}"
  tags  = local.tags
}

resource "aws_ssm_parameter" "helix_core_topology" {
  name  = "/${var.project_prefix}/${var.environment}/perforce/topology"
  type  = "String"
  value = jsonencode(local.topology)
  
  description = "Perforce Helix Core Server Topology"
  
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-topology"
  })
}

