# Note: AD users are assumed to already exist in the domain
# The VDI module integrates with existing AD infrastructure
# For examples of creating AD users, see examples/create-resources-complete/

# Key Pairs
resource "tls_private_key" "vdi_keys" {
  for_each  = { for user, config in local.processed_vdi_config : user => config if config.create_key_pair && config.key_pair_name == null }
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vdi_key_pairs" {
  for_each   = tls_private_key.vdi_keys
  key_name   = "${var.project_prefix}-${each.key}-vdi-key"
  public_key = each.value.public_key_openssh
  tags       = local.processed_vdi_config[each.key].tags
}

# Launch Templates & Instances
resource "aws_launch_template" "vdi_launch_templates" {
  for_each      = local.processed_vdi_config
  name_prefix   = "${var.project_prefix}-${each.key}-vdi-"
  image_id      = each.value.ami
  instance_type = each.value.instance_type
  key_name      = try(aws_key_pair.vdi_key_pairs[each.key].key_name, each.value.key_pair_name, null)

  network_interfaces {
    subnet_id                   = each.value.subnet_id
    associate_public_ip_address = each.value.associate_public_ip_address
    security_groups             = each.value.create_default_security_groups ? [aws_security_group.vdi_default_sg[each.key].id] : each.value.existing_security_groups
  }

  iam_instance_profile { name = coalesce(each.value.iam_instance_profile, aws_iam_instance_profile.vdi_instance_profile.name) }

  # Enforce IMDSv2 for security
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Root volume
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = each.value.volumes.Root.capacity
      volume_type           = each.value.volumes.Root.type
      iops                  = each.value.volumes.Root.type == "gp3" ? each.value.volumes.Root.iops : null
      throughput            = each.value.volumes.Root.type == "gp3" ? each.value.volumes.Root.throughput : null
      delete_on_termination = true
      encrypted             = local.storage_settings.encryption_enabled
      kms_key_id            = local.storage_settings.kms_key_id
    }
  }

  # Additional volumes
  dynamic "block_device_mappings" {
    for_each = { for vol_name, vol_config in each.value.volumes : vol_name => vol_config if vol_name != "Root" }
    content {
      device_name = "/dev/xvd${substr("fghijklmnopqrstuvwxyz", index(keys(each.value.volumes), block_device_mappings.key) - 1, 1)}"
      ebs {
        volume_size           = block_device_mappings.value.capacity
        volume_type           = block_device_mappings.value.type
        iops                  = block_device_mappings.value.type == "gp3" ? block_device_mappings.value.iops : null
        throughput            = block_device_mappings.value.type == "gp3" ? block_device_mappings.value.throughput : null
        delete_on_termination = true
        encrypted             = local.storage_settings.encryption_enabled
        kms_key_id            = local.storage_settings.kms_key_id
      }
    }
  }

  user_data = null

  tag_specifications {
    resource_type = "instance"
    tags          = each.value.tags
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(each.value.tags, { Name = "${var.project_prefix}-${each.key}-vdi-volume" })
  }
  tags = each.value.tags
}

resource "aws_instance" "vdi_instances" {
  # checkov:skip=CKV_AWS_126:Detailed monitoring not required for VDI workstation instances
  # checkov:skip=CKV2_AWS_41:IAM role is attached to instances via iam_instance_profile in launch template
  # checkov:skip=CKV_AWS_79:IMDSv2 is properly configured in launch template with http_tokens=required
  # checkov:skip=CKV_AWS_135:EBS optimization not applicable for selected instance types
  # checkov:skip=CKV_AWS_8:EBS encryption is controlled by module variable ebs_encryption_enabled
  for_each          = local.processed_vdi_config
  availability_zone = each.value.availability_zone
  tags              = each.value.tags

  launch_template {
    id      = aws_launch_template.vdi_launch_templates[each.key].id
    version = "$Latest"
  }

  lifecycle { create_before_destroy = true }
}
