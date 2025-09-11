# VDI Module - Local Windows user management with EC2 workstations

# VDI Workstation EC2 Instances

# Key pairs for emergency access (always created)
resource "aws_key_pair" "workstation_keys" {
  for_each = var.workstation_assignments
  
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
  for_each = var.workstation_assignments
  
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private keys in S3 for emergency access
resource "aws_s3_object" "emergency_private_keys" {
  for_each = var.workstation_assignments
  
  bucket = aws_s3_bucket.keys.id
  key    = "${each.key}/ec2-key/${each.key}-private-key.pem"
  content = tls_private_key.workstation_keys[each.key].private_key_pem
  
  server_side_encryption = "AES256"
  
  tags = {
    Workstation = each.key
    Purpose     = "VDI Emergency Key"
  }
}

# VDI Workstation EC2 Instances
resource "aws_instance" "workstations" {
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
  
  # Metadata options for security
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    http_put_response_hop_limit = 1
  }
  
  # Instance tags
  tags = merge(each.value.tags, {
    Name             = "${local.name_prefix}-${each.key}"
    WorkstationKey   = each.key
    AssignedUser     = var.workstation_assignments[each.key].user
    "VDI-Workstation" = each.key  # Used by SSM association for targeting
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
    for workstation_key, config in var.workstation_assignments : workstation_key => config
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
}# Centralized Logging Resources
# Single log group for all VDI components

# Single log group for all VDI logs
resource "aws_cloudwatch_log_group" "vdi_logs" {
  count = var.enable_centralized_logging ? 1 : 0
  
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  
  tags = merge(var.tags, {
    Name    = local.log_group_name
    Purpose = "VDI All Logs"
    Type    = "CloudWatch Log Group"
  })
}# Secrets Manager for VDI User Passwords

# Secrets for ALL users (admin users on ALL workstations, standard users on assigned workstations)
resource "aws_secretsmanager_secret" "user_passwords" {
  for_each = local.workstation_user_combinations
  
  name = "${var.project_prefix}/${each.value.workstation}/users/${each.value.user}"
  description = "Password for ${var.users[each.value.user].type} user ${each.value.user} on workstation ${each.value.workstation}"
  
  recovery_window_in_days = 0  # Force immediate deletion without recovery window
  
  tags = merge(var.tags, {
    Purpose = "VDI User Password"
    User = each.value.user
    Workstation = each.value.workstation
    UserType = var.users[each.value.user].type
  })
}

# VDIAdmin is now handled in the unified user_passwords resources above

# Generate random passwords for ALL users (back to original working approach)
resource "random_password" "user_passwords" {
  for_each = local.workstation_user_combinations
  
  length  = 16
  special = true
  
  # Regenerate password when assigned instance changes
  keepers = {
    instance_id = aws_instance.workstations[each.value.workstation].id
  }
}

# Store ALL user passwords in Secrets Manager with connectivity info
resource "aws_secretsmanager_secret_version" "user_passwords" {
  for_each = local.workstation_user_combinations
  
  secret_id = aws_secretsmanager_secret.user_passwords[each.key].id
  secret_string = jsonencode({
    # User credentials
    username = each.value.user
    password = random_password.user_passwords[each.key].result
    
    # User details
    given_name = var.users[each.value.user].given_name
    family_name = var.users[each.value.user].family_name
    email = var.users[each.value.user].email
    user_type = var.users[each.value.user].type
    workstation = each.value.workstation
    
    # Connectivity information
    connectivity = {
      private_ip = aws_instance.workstations[each.value.workstation].private_ip
      public_ip = aws_instance.workstations[each.value.workstation].public_ip
      private_dns = aws_instance.workstations[each.value.workstation].private_dns
      public_dns = aws_instance.workstations[each.value.workstation].public_dns
      dcv_web_url = "https://${aws_instance.workstations[each.value.workstation].public_ip}:8443"
      dcv_native_port = 8443
      instance_id = aws_instance.workstations[each.value.workstation].id
    }
  })
}

# VDIAdmin password versions are managed by user data script