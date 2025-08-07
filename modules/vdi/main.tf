# VDI Instance Configuration

# Generate a key pair if one is not provided
resource "tls_private_key" "vdi_key" {
  count     = var.key_pair_name == null && var.create_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vdi_key_pair" {
  count      = var.key_pair_name == null && var.create_key_pair ? 1 : 0
  key_name   = "${var.project_prefix}-${var.name}-key"
  public_key = tls_private_key.vdi_key[0].public_key_openssh

  tags = var.tags
}

# Store secrets in AWS Secrets Manager if enabled
resource "aws_secretsmanager_secret" "vdi_secrets" {
  count                   = var.store_passwords_in_secrets_manager ? 1 : 0
  name                    = "${var.project_prefix}-${var.name}-secrets-${random_id.secret_suffix[0].hex}"
  recovery_window_in_days = 0 # Force immediate deletion for development
  tags                    = var.tags
}

# Random suffix to avoid naming conflicts
resource "random_id" "secret_suffix" {
  count       = var.store_passwords_in_secrets_manager ? 1 : 0
  byte_length = 4
}

resource "aws_secretsmanager_secret_version" "vdi_secrets" {
  count     = var.store_passwords_in_secrets_manager ? 1 : 0
  secret_id = aws_secretsmanager_secret.vdi_secrets[0].id

  secret_string = jsonencode({
    private_key           = var.key_pair_name == null && var.create_key_pair ? tls_private_key.vdi_key[0].private_key_pem : null
    windows_admin_password = var.admin_password
    ad_admin_password     = var.ad_admin_password != "" ? var.ad_admin_password : null
    effective_password    = local.effective_password
    domain_join_enabled   = local.enable_domain_join
    password_type         = local.enable_domain_join ? "AD admin password" : "Local admin password"
  })
}

# Launch template for the VDI instance
resource "aws_launch_template" "vdi_launch_template" {
  name_prefix   = "${var.project_prefix}-${var.name}-vdi-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name != null ? var.key_pair_name : (var.create_key_pair ? aws_key_pair.vdi_key_pair[0].key_name : null)

  # Security groups are specified only in network_interfaces, not at the top level
  network_interfaces {
    subnet_id                   = var.subnet_id
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = [aws_security_group.vdi_sg.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.vdi_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      iops                  = var.root_volume_type == "gp3" ? var.root_volume_iops : null
      throughput            = var.root_volume_type == "gp3" ? var.root_volume_throughput : null
      delete_on_termination = true
      encrypted             = var.ebs_encryption_enabled
      kms_key_id            = var.ebs_kms_key_id
    }
  }

  # Additional EBS volumes if specified
  dynamic "block_device_mappings" {
    for_each = var.additional_ebs_volumes
    content {
      device_name = block_device_mappings.value.device_name
      ebs {
        volume_size           = block_device_mappings.value.volume_size
        volume_type           = block_device_mappings.value.volume_type
        iops                  = block_device_mappings.value.volume_type == "gp3" ? block_device_mappings.value.iops : null
        throughput            = block_device_mappings.value.volume_type == "gp3" ? block_device_mappings.value.throughput : null
        delete_on_termination = block_device_mappings.value.delete_on_termination
        encrypted             = var.ebs_encryption_enabled
        kms_key_id            = var.ebs_kms_key_id
      }
    }
  }

  user_data = local.encoded_user_data

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.project_prefix}-${var.name}-vdi"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.project_prefix}-${var.name}-vdi-volume"
    })
  }

  tags = var.tags
}

# EC2 instance for VDI
resource "aws_instance" "vdi_instance" {
  count = var.create_instance ? 1 : 0

  launch_template {
    id      = aws_launch_template.vdi_launch_template.id
    version = "$Latest"
  }

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-vdi"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Note: Validation resources are defined in locals.tf