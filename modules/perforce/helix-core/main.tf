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
    /home/ec2-user/gpic_scripts/p4_configure.sh --hx_logs /dev/sdf --hx_metadata /dev/sdg --hx_depots /dev/sdh \
     --p4d_type ${var.server_type} \
     --username ${var.helix_core_super_user_username_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_username[0].secret_id : var.helix_core_super_user_username_secret_arn} \
     --password ${var.helix_core_super_user_password_secret_arn == null ? awscc_secretsmanager_secret.helix_core_super_user_password[0].secret_id : var.helix_core_super_user_password_secret_arn} \
     --fqdn ${var.FQDN == null ? "" : var.FQDN} \
     --auth ${var.helix_authentication_service_url == null ? "" : var.helix_authentication_service_url}
  EOT


  vpc_security_group_ids = concat(var.existing_security_groups, [aws_security_group.helix_core_security_group[0].id])

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
# Storage Configuration
##########################################

// hxlogs
resource "aws_ebs_volume" "logs" {
  availability_zone = local.helix_core_az
  size              = var.logs_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = local.tags
}

resource "aws_volume_attachment" "logs_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.logs.id
  instance_id = aws_instance.helix_core_instance.id
}

// hxmetadata
resource "aws_ebs_volume" "metadata" {
  availability_zone = local.helix_core_az
  size              = var.metadata_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = local.tags
}

resource "aws_volume_attachment" "metadata_attachment" {
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.metadata.id
  instance_id = aws_instance.helix_core_instance.id
}

// hxdepot
resource "aws_ebs_volume" "depot" {
  availability_zone = local.helix_core_az
  size              = var.depot_volume_size
  encrypted         = true
  #checkov:skip=CKV_AWS_189: CMK encryption not supported currently
  tags = local.tags
}

resource "aws_volume_attachment" "depot_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.depot.id
  instance_id = aws_instance.helix_core_instance.id
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
