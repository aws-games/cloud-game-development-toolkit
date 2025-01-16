##########################################
# Perforce Helix Core Super User
##########################################

resource "awscc_secretsmanager_secret" "helix_core_super_user_password" {
  count       = var.helix_core_super_user_password_secret_arn == null ? 1 : 0
  name        = "perforceHelixCoreSuperUserPassword"
  description = "The password for the created Helix Core super user."
  generate_secret_string = {
    exclude_numbers     = false
    exclude_punctuation = true
    include_space       = false
  }
}

resource "awscc_secretsmanager_secret" "helix_core_super_user_username" {
  count         = var.helix_core_super_user_username_secret_arn == null ? 1 : 0
  name          = "perforceHelixCoreSuperUserUsername"
  secret_string = "perforce"
}


##########################################
# Perforce Helix Core Instance
##########################################

resource "aws_instance" "helix_core_instance" {
  ami           = data.aws_ami.helix_core_ami.id
  instance_type = var.instance_type

  availability_zone = local.helix_core_az
  subnet_id         = var.instance_subnet_id

  iam_instance_profile = aws_iam_instance_profile.helix_core_instance_profile.id

  user_data = <<-EOT
    #!/bin/bash
    EBS_LOGS_NAME="${var.storage_type == "FSxN" ? "${aws_fsx_ontap_storage_virtual_machine.helix_core_svm[0].id}.${aws_fsx_ontap_file_system.helix_core_fs[0].id}.fsx.${var.fsxn_region}.amazonaws.com:/hxlogs" : "/dev/sdf"}"
    EBS_METADATA_NAME="${var.storage_type == "FSxN" ? "${aws_fsx_ontap_storage_virtual_machine.helix_core_svm[0].id}.${aws_fsx_ontap_file_system.helix_core_fs[0].id}.fsx.${var.fsxn_region}.amazonaws.com:/hxmetadata" : "/dev/sdg"}"
    EBS_DEPOTS_NAME="${var.storage_type == "FSxN" ? "${aws_fsx_ontap_storage_virtual_machine.helix_core_svm[0].id}.${aws_fsx_ontap_file_system.helix_core_fs[0].id}.fsx.${var.fsxn_region}.amazonaws.com:/hxdepots" : "/dev/sdh"}"
    /home/ec2-user/gpic_scripts/p4_configure.sh --hx_logs $EBS_LOGS_NAME \
     --hx_metadata $EBS_METADATA_NAME \
     --hx_depots $EBS_DEPOTS_NAME \
     --p4d_type ${var.server_type} \
     --username ${var.helix_core_super_user_username_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_username[0].secret_id : var.helix_core_super_user_username_secret_arn} \
     --password ${var.helix_core_super_user_password_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_password[0].secret_id : var.helix_core_super_user_password_secret_arn} \
     ${var.fully_qualified_domain_name == null ? "" : "--fqdn ${var.fully_qualified_domain_name}"} \
     ${var.helix_authentication_service_url == null ? "" : "--auth ${var.helix_authentication_service_url}"} \
     --case_sensitive ${var.helix_case_sensitive ? 1 : 0} \
     --unicode ${var.unicode ? "true" : "false"} \
     --selinux ${var.selinux ? "true" : "false"} \
     --plaintext ${var.plaintext ? "true" : "false"}

  EOT

  vpc_security_group_ids = (var.create_default_sg ?
    concat(var.existing_security_groups, [aws_security_group.helix_core_security_group[0].id]) :
  var.existing_security_groups)

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
    Name = "${local.name_prefix}-${var.server_type}-${local.helix_core_az}"
  })
}

##########################################
# EIP For Internet Access to Instance
##########################################

resource "aws_eip" "helix_core_eip" {
  count    = var.internal ? 0 : 1
  instance = aws_instance.helix_core_instance.id
  domain   = "vpc"
}

##########################################
# FSx ONTAP File System
##########################################

resource "aws_fsx_ontap_file_system" "helix_core_fs" {
  count               = var.storage_type == "FSxN" ? 1 : 0
  storage_capacity    = 1024
  subnet_ids          = [var.instance_subnet_id]
  preferred_subnet_id = var.instance_subnet_id
  deployment_type     = "SINGLE_AZ_1"
  throughput_capacity = 128

  tags = local.tags
}

resource "aws_fsx_ontap_storage_virtual_machine" "helix_core_svm" {
  count          = var.storage_type == "FSxN" ? 1 : 0
  file_system_id = aws_fsx_ontap_file_system.helix_core_fs[count.index].id
  name           = "helix_core_svm"
  tags           = local.tags
}

##########################################
# Storage Configuration - EBS
##########################################

// hxlogs
resource "aws_ebs_volume" "logs" {
  count             = var.storage_type == "EBS" ? 1 : 0
  availability_zone = local.helix_core_az
  size              = var.logs_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = local.tags
}

resource "aws_volume_attachment" "logs_attachment" {
  count       = var.storage_type == "EBS" ? 1 : 0
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.logs[count.index].id
  instance_id = aws_instance.helix_core_instance.id
}

// hxmetadata
resource "aws_ebs_volume" "metadata" {
  count             = var.storage_type == "EBS" ? 1 : 0
  availability_zone = local.helix_core_az
  size              = var.metadata_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = local.tags
}

resource "aws_volume_attachment" "metadata_attachment" {
  count       = var.storage_type == "EBS" ? 1 : 0
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.metadata[count.index].id
  instance_id = aws_instance.helix_core_instance.id
}

// hxdepot
resource "aws_ebs_volume" "depot" {
  count             = var.storage_type == "EBS" ? 1 : 0
  availability_zone = local.helix_core_az
  size              = var.depot_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = local.tags
}

resource "aws_volume_attachment" "depot_attachment" {
  count       = var.storage_type == "EBS" ? 1 : 0
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.depot[count.index].id
  instance_id = aws_instance.helix_core_instance.id
}

##########################################
# Storage Configuration - FSxN
##########################################

// hxlogs
resource "aws_fsx_ontap_volume" "logs" {
  count                      = var.storage_type == "FSxN" ? 1 : 0
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.helix_core_svm[count.index].id
  name                       = "logs"
  size_in_megabytes          = var.logs_volume_size * 1024
  tags                       = local.tags
  storage_efficiency_enabled = true
  junction_path              = "/hxlogs"
}

// hxmetadata
resource "aws_fsx_ontap_volume" "metadata" {
  count                      = var.storage_type == "FSxN" ? 1 : 0
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.helix_core_svm[count.index].id
  name                       = "metadata"
  size_in_megabytes          = var.metadata_volume_size * 1024
  tags                       = local.tags
  storage_efficiency_enabled = true
  junction_path              = "/hxmetadata"
}

// hxdepot
resource "aws_fsx_ontap_volume" "depot" {
  count                      = var.storage_type == "FSxN" ? 1 : 0
  storage_virtual_machine_id = aws_fsx_ontap_storage_virtual_machine.helix_core_svm[count.index].id
  name                       = "depot"
  size_in_megabytes          = var.depot_volume_size * 1024
  tags                       = local.tags
  storage_efficiency_enabled = true
  junction_path              = "/hxdepots"
}

##########################################
# Default SG for Internet Egress
##########################################

resource "aws_security_group" "helix_core_security_group" {
  count = var.create_default_sg ? 1 : 0
  #checkov:skip=CKV2_AWS_5:SG is attahced to FSxZ file systems

  vpc_id      = var.vpc_id
  name        = "${local.name_prefix}-instance"
  description = "Security group for Helix Core machines."
  tags        = local.tags
}

resource "aws_vpc_security_group_egress_rule" "helix_core_internet" {
  count             = var.create_default_sg ? 1 : 0
  security_group_id = aws_security_group.helix_core_security_group[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
  description       = "Helix Core out to Internet"
}
