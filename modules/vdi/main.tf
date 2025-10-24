# VDI Module - Local Windows user management with EC2 workstations

# VDI Workstation EC2 Instances

# Key pairs for emergency access (always created)
resource "aws_key_pair" "workstation_keys" {
  for_each = var.workstations

  key_name   = "${local.name_prefix}-${each.key}-emergency-key"
  public_key = tls_private_key.workstation_keys[each.key].public_key_openssh

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${each.key}-emergency-key"
    Workstation = each.key
    Purpose     = "VDI Emergency Access"
  })
}

# Private keys for emergency access
resource "tls_private_key" "workstation_keys" {
  for_each = var.workstations

  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private keys in S3 for emergency access
resource "aws_s3_object" "emergency_private_keys" {
  for_each = var.workstations

  bucket  = aws_s3_bucket.keys.id
  key     = "${each.key}/ec2-key/${each.key}-private-key.pem"
  content = tls_private_key.workstation_keys[each.key].private_key_pem

  server_side_encryption = "AES256"

  tags = {
    Workstation = each.key
    Purpose     = "VDI Emergency Key"
  }
}

# VDI Workstation EC2 Instances
resource "aws_instance" "workstations" {
  #checkov:skip=CKV_AWS_126:Detailed monitoring not required for VDI workstations - adds cost without significant benefit
  #checkov:skip=CKV_AWS_135:EBS optimization not required - workstation performance adequate without it
  for_each = local.final_instances

  # Basic configuration
  ami           = each.value.ami
  instance_type = each.value.instance_type
  key_name      = aws_key_pair.workstation_keys[each.key].key_name

  # Network configuration
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = each.value.security_groups
  associate_public_ip_address = each.value.associate_public_ip_address
  availability_zone           = each.value.availability_zone

  # IAM configuration
  iam_instance_profile = each.value.iam_instance_profile != null ? each.value.iam_instance_profile : aws_iam_instance_profile.vdi_instance_profile[each.key].name

  # Root volume configuration
  root_block_device {
    volume_type = each.value.volumes["Root"].type
    volume_size = each.value.volumes["Root"].capacity
    iops        = each.value.volumes["Root"].iops
    throughput  = each.value.volumes["Root"].throughput
    encrypted   = each.value.volumes["Root"].encrypted
    kms_key_id  = var.ebs_kms_key_id

    tags = merge(var.tags, {
      Name        = "${local.name_prefix}-${each.key}-root-volume"
      Workstation = each.key
      VolumeType  = "Root"
    })
  }

  # Additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = {
      for volume_name, volume_config in each.value.volumes : volume_name => volume_config
      if volume_name != "Root"
    }

    content {
      device_name = ebs_block_device.value.device_name
      volume_type = ebs_block_device.value.type
      volume_size = ebs_block_device.value.capacity
      iops        = ebs_block_device.value.iops
      throughput  = ebs_block_device.value.throughput
      encrypted   = ebs_block_device.value.encrypted
      kms_key_id  = var.ebs_kms_key_id

      tags = merge(var.tags, {
        Name         = "${local.name_prefix}-${each.key}-${ebs_block_device.key}-volume"
        Workstation  = each.key
        VolumeType   = ebs_block_device.key
        WindowsDrive = ebs_block_device.value.windows_drive
      })
    }
  }

  # No user data - using SSM for more reliable and debuggable configuration
  # All VDI setup handled by SSM associations

  # Enable automatic instance replacement when user data changes
  user_data_replace_on_change = true

  # Capacity reservation specification for ODCR support
  dynamic "capacity_reservation_specification" {
    for_each = each.value.capacity_reservation_preference != null ? [1] : []
    content {
      capacity_reservation_preference = each.value.capacity_reservation_preference
    }
  }

  # Configure instance store for temp/cache usage
  ephemeral_block_device {
    device_name  = "/dev/sdb"
    virtual_name = "ephemeral0"
  }

  # Metadata options for security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Instance tags
  tags = merge(each.value.tags, {
    Name              = "${local.name_prefix}-${each.key}"
    WorkstationKey    = each.key
    AssignedUser      = each.value.assigned_user
    "VDI-Workstation" = each.key # Used by SSM association for targeting
  })



  depends_on = [
    aws_iam_instance_profile.vdi_instance_profile,
    aws_s3_bucket.keys,
    aws_s3_bucket.scripts
  ]
}

# Elastic IPs for workstations (optional)
resource "aws_eip" "workstation_eips" {
  for_each = {
    for workstation_key, config in var.workstations : workstation_key => config
    if lookup(config, "allocate_eip", false)
  }

  instance = aws_instance.workstations[each.key].id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${each.key}-eip"
    Workstation = each.key
    Purpose     = "VDI Static IP"
  })

  depends_on = [aws_instance.workstations]
} # Centralized Logging Resources
# Single log group for all VDI components

# Single log group for all VDI logs
resource "aws_cloudwatch_log_group" "vdi_logs" {
  #checkov:skip=CKV_AWS_338:1 year log retention not required for VDI logs - 30 days sufficient for troubleshooting
  #checkov:skip=CKV_AWS_158:KMS encryption not required for VDI logs - default encryption sufficient
  count = var.enable_centralized_logging ? 1 : 0

  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = local.log_group_name
    Purpose = "VDI All Logs"
    Type    = "CloudWatch Log Group"
  })
} # Secrets Manager for VDI User Passwords

# Secrets for ALL users with AWS auto-generated passwords - NO passwords in Terraform state!
# Uses AWSCC provider for secure password generation directly in AWS Secrets Manager
resource "awscc_secretsmanager_secret" "user_passwords" {
  for_each = local.workstation_user_combinations

  name        = "${var.project_prefix}/${each.value.workstation}/users/${each.value.user}"
  description = "Password for ${var.users[each.value.user].type} user ${each.value.user} on workstation ${each.value.workstation}"

  # AWS auto-generates secure passwords - no passwords in Terraform state!
  generate_secret_string = {
    secret_string_template = jsonencode({
      username = each.value.user
      given_name = var.users[each.value.user].given_name
      family_name = var.users[each.value.user].family_name
      email = var.users[each.value.user].email
      user_type = var.users[each.value.user].type
      workstation = each.value.workstation
      instance_id = aws_instance.workstations[each.value.workstation].id
    })
    generate_string_key        = "password" # AWS generates this key
    password_length            = 16
    include_space              = false
    exclude_lowercase          = false
    exclude_uppercase          = false
    exclude_numbers            = false
    exclude_punctuation        = false # Include special characters
    exclude_characters         = "\"'`$\\|&<>;#%()" # Exclude PowerShell problematic chars
    require_each_included_type = true   # Force inclusion of each character type
  }

  tags = [
    {
      key   = "Purpose"
      value = "VDI User Password"
    },
    {
      key   = "User"
      value = each.value.user
    },
    {
      key   = "Workstation"
      value = each.value.workstation
    },
    {
      key   = "UserType"
      value = var.users[each.value.user].type
    }
  ]


}

# DNS parameters for connectivity
resource "aws_ssm_parameter" "vdi_dns" {
  for_each = local.workstation_user_combinations

  name  = "/${var.project_prefix}/${each.value.workstation}/users/${each.value.user}/dns"
  type  = "String"
  value = jsonencode({
    private_dns = "https://${aws_instance.workstations[each.value.workstation].private_dns}:8443"
    public_dns = "https://${aws_instance.workstations[each.value.workstation].public_dns}:8443"
    custom_dns = var.users[each.value.user].type != "fleet_administrator" ? "https://${each.value.user}.${local.private_zone_name}:8443" : "null"
  })

  tags = merge(var.tags, {
    Purpose     = "VDI DNS"
    User        = each.value.user
    Workstation = each.value.workstation
  })
}