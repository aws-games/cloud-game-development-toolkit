##########################################
# Perforce P4 Server Super User
##########################################
resource "awscc_secretsmanager_secret" "super_user_password" {
  count       = var.super_user_password_secret_arn == null ? 1 : 0
  name        = "${local.name_prefix}-SuperUserPassword"
  description = "The password for the created P4 Server super user."
  generate_secret_string = {
    exclude_numbers     = false
    exclude_punctuation = true
    include_space       = false
  }
}

resource "awscc_secretsmanager_secret" "super_user_username" {
  count         = var.super_user_username_secret_arn == null ? 1 : 0
  name          = "${local.name_prefix}-SuperUserUsername"
  description   = "The username for the created P4 Server super user."
  secret_string = "perforce"
}


##########################################
# Perforce P4 Server Instance
##########################################
locals {
  is_iscsi = var.protocol == "ISCSI"
  is_fsxn  = var.storage_type == "FSxN"
  is_ebs   = var.storage_type == "EBS"

  iscsi_depot_volume = (local.is_iscsi ?
    "/dev/mapper/${aws_fsx_ontap_volume.depot[0].name}" :
    null
  )
  nfs_depot_volume = (local.is_fsxn && !local.is_iscsi ?
    "${var.amazon_fsxn_svm_id}.${var.amazon_fsxn_filesystem_id}.fsx.${var.fsxn_region}.amazonaws.com:${aws_fsx_ontap_volume.depot[0].junction_path}"
    : null
  )
  ebs_depot_volume = local.is_ebs ? "/dev/sdf" : null
  depot_volume_name = (local.is_fsxn ?
    (local.is_iscsi ? local.iscsi_depot_volume : local.nfs_depot_volume) :
    local.ebs_depot_volume
  )

  iscsi_metadata_volume = (local.is_fsxn && local.is_iscsi ?
    "/dev/mapper/${aws_fsx_ontap_volume.metadata[0].name}" :
    null
  )
  nfs_metadata_volume = (local.is_fsxn && !local.is_iscsi ?
    "${var.amazon_fsxn_svm_id}.${var.amazon_fsxn_filesystem_id}.fsx.${var.fsxn_region}.amazonaws.com:${aws_fsx_ontap_volume.metadata[0].junction_path}"
    :
    null
  )
  ebs_metadata_volume = local.is_ebs ? "/dev/sdg" : null
  metadata_volume_name = (local.is_fsxn ?
    (local.is_iscsi ? local.iscsi_metadata_volume : local.nfs_metadata_volume) :
    local.ebs_metadata_volume
  )

  iscsi_logs_volume = (local.is_iscsi ?
    "/dev/mapper/${aws_fsx_ontap_volume.logs[0].name}" :
    null
  )
  nfs_logs_volume = (local.is_fsxn && !local.is_iscsi ?
    "${var.amazon_fsxn_svm_id}.${var.amazon_fsxn_filesystem_id}.fsx.${var.fsxn_region}.amazonaws.com:${aws_fsx_ontap_volume.logs[0].junction_path}"
    :
    null
  )
  ebs_logs_volume = local.is_ebs ? "/dev/sdh" : null
  logs_volume_name = (local.is_fsxn ?
    (local.is_iscsi ? local.iscsi_logs_volume : local.nfs_logs_volume) :
    local.ebs_logs_volume
  )
}

locals {
  username_secret = var.super_user_username_secret_arn == null ? awscc_secretsmanager_secret.super_user_username[0].secret_id : var.super_user_username_secret_arn
  password_secret = var.super_user_password_secret_arn == null ? awscc_secretsmanager_secret.super_user_password[0].secret_id : var.super_user_password_secret_arn
}
resource "aws_instance" "server_instance" {
  ami           = data.aws_ami.existing_server_ami.id
  instance_type = var.instance_type

  availability_zone = local.p4_server_az
  subnet_id         = var.instance_subnet_id
  private_ip        = var.instance_private_ip

  iam_instance_profile = aws_iam_instance_profile.instance_profile.id

  user_data = templatefile("${path.module}/templates/user_data.tftpl", {
    depot_volume_name    = local.depot_volume_name
    metadata_volume_name = local.metadata_volume_name
    logs_volume_name     = local.logs_volume_name
    p4_server_type       = var.p4_server_type
    username_secret      = local.username_secret
    password_secret      = local.password_secret
    fqdn                 = var.fully_qualified_domain_name != null ? var.fully_qualified_domain_name : ""
    auth_url             = var.auth_service_url != null ? var.auth_service_url : ""
    is_fsxn              = local.is_fsxn
    fsxn_password        = var.fsxn_password
    fsxn_svm_name        = var.fsxn_svm_name
    fsxn_management_ip   = var.fsxn_management_ip
    case_sensitive       = var.case_sensitive ? 1 : 0
    unicode              = var.unicode ? "true" : "false"
    selinux              = var.selinux ? "true" : "false"
    plaintext            = var.plaintext ? "true" : "false"
  })

  vpc_security_group_ids = (var.create_default_sg ?
    concat(var.existing_security_groups, [aws_security_group.default_security_group[0].id]) :
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
    Name = "${local.name_prefix}-${var.p4_server_type}-${local.p4_server_az}"
  })

  depends_on = [
    netapp-ontap_san_lun-map.depots_lun_map,
    netapp-ontap_san_lun-map.logs_lun_map,
    netapp-ontap_san_lun-map.metadata_lun_map
  ]
}


##########################################
# EIP For Internet Access to Instance
##########################################
resource "aws_eip" "server_eip" {
  count    = var.internal ? 0 : 1
  instance = aws_instance.server_instance.id
  domain   = "vpc"
}

##########################################
# Storage Configuration - EBS
##########################################
// hxdepot
resource "aws_ebs_volume" "depot" {
  count             = var.storage_type == "EBS" ? 1 : 0
  availability_zone = local.p4_server_az
  size              = var.depot_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-depot-volume"
  })
}
resource "aws_volume_attachment" "depot_attachment" {
  count       = var.storage_type == "EBS" ? 1 : 0
  device_name = local.ebs_depot_volume
  volume_id   = aws_ebs_volume.depot[count.index].id
  instance_id = aws_instance.server_instance.id
}

// hxmetadata
resource "aws_ebs_volume" "metadata" {
  count             = var.storage_type == "EBS" ? 1 : 0
  availability_zone = local.p4_server_az
  size              = var.metadata_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-metadata-volume"
  })
}

resource "aws_volume_attachment" "metadata_attachment" {
  count       = var.storage_type == "EBS" ? 1 : 0
  device_name = local.ebs_metadata_volume
  volume_id   = aws_ebs_volume.metadata[count.index].id
  instance_id = aws_instance.server_instance.id
}

// hxlogs
resource "aws_ebs_volume" "logs" {
  count             = var.storage_type == "EBS" ? 1 : 0
  availability_zone = local.p4_server_az
  size              = var.logs_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-logs-volume"
  })
}
resource "aws_volume_attachment" "logs_attachment" {
  count       = var.storage_type == "EBS" ? 1 : 0
  device_name = local.ebs_logs_volume
  volume_id   = aws_ebs_volume.logs[count.index].id
  instance_id = aws_instance.server_instance.id
}
