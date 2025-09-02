# Local variables for the VDI module
locals {
  # Default AMI ID from data source
  default_ami_id = length(data.aws_ami.windows_server_2025_vdi) > 0 ? data.aws_ami.windows_server_2025_vdi[0].id : null

  # User's public IP for security group access (if auto-detection is enabled)
  user_public_ip_cidr = var.auto_detect_public_ip ? "${chomp(data.http.user_public_ip[0].response_body)}/32" : null

  # Storage configuration
  storage_settings = {
    encryption_enabled = var.ebs_encryption_enabled
    kms_key_id         = var.ebs_kms_key_id
  }

  # Check if any user requires AD joining AND AD integration is enabled
  any_ad_join_required = var.enable_ad_integration && anytrue([for user, config in var.vdi_config : config.join_ad])

  # Process each user's configuration with defaults
  processed_vdi_config = {
    for user, config in var.vdi_config : user => {
      # Compute
      ami           = config.ami != null ? config.ami : local.default_ami_id
      instance_type = config.instance_type

      # Networking
      availability_zone = config.availability_zone != null ? config.availability_zone : data.aws_availability_zones.available.names[0]
      subnet_id         = config.subnet_id != null ? config.subnet_id : (length(var.subnets) > 0 ? var.subnets[0] : null)

      # Security
      iam_instance_profile           = config.iam_instance_profile
      create_default_security_groups = config.create_default_security_groups
      existing_security_groups       = config.existing_security_groups
      allowed_cidr_blocks            = length(config.allowed_cidr_blocks) > 0 ? config.allowed_cidr_blocks : var.allowed_cidr_blocks

      # Key Pair
      key_pair_name   = config.key_pair_name
      create_key_pair = config.create_key_pair

      # Password - use provided password or null (AMI will generate)
      admin_password = config.admin_password != null ? config.admin_password : (
        config.join_ad && var.directory_id != null ? lookup(var.individual_user_passwords, user, null) : null
      )

      # Storage
      volumes = config.volumes

      # Active Directory - only if AD integration is enabled
      join_ad = config.join_ad && var.enable_ad_integration

      # Always-true behaviors (hardcoded for simplicity)
      associate_public_ip_address        = true # VDI needs internet access
      store_passwords_in_secrets_manager = true # Secure credential storage essential

      # Tags
      tags = merge(var.tags, config.tags != null ? config.tags : {}, {
        User        = user
        Name        = "${var.project_prefix}-${user}-vdi"
        Environment = var.environment
      })
    }
  }
}
