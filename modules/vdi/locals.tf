# Local variables for the VDI module
locals {
  # Default AMI ID from data source
  default_ami_id = length(data.aws_ami.windows_server_2025_vdi) > 0 ? data.aws_ami.windows_server_2025_vdi[0].id : null
  
  # User's public IP for security group access (if auto-detection is enabled)
  user_public_ip_cidr = var.auto_detect_public_ip ? "${chomp(data.http.user_public_ip[0].response_body)}/32" : null
  
  # Check if any user requires AD joining AND AD integration is enabled
  any_ad_join_required = var.enable_ad_integration && anytrue([for user, config in var.vdi_config : config.join_ad])
  
  # All users who join AD will get the shared temporary password (only if AD integration is enabled)
  users_joining_ad = var.enable_ad_integration ? {
    for user, config in var.vdi_config : user => config
    if config.join_ad
  } : {}
  
  # Validation: Check if AD configuration is complete when needed
  users_wanting_ad = [for user, config in var.vdi_config : user if config.join_ad]
  ad_config_incomplete = length(local.users_wanting_ad) > 0 && (
    var.directory_id == null || 
    var.directory_name == null || 
    var.shared_temp_password == null
  )
  
  # Process each user's configuration with defaults
  processed_vdi_config = {
    for user, config in var.vdi_config : user => {
      # Compute
      ami           = config.ami != null ? config.ami : local.default_ami_id
      instance_type = config.instance_type
      
      # Networking
      availability_zone               = config.availability_zone
      subnet_id                      = config.subnet_id
      associate_public_ip_address    = config.associate_public_ip_address
      
      # Security
      iam_instance_profile           = config.iam_instance_profile
      create_default_security_groups = config.create_default_security_groups
      existing_security_groups       = config.existing_security_groups
      allowed_cidr_blocks           = config.allowed_cidr_blocks
      
      # Key Pair
      key_pair_name   = config.key_pair_name
      create_key_pair = config.create_key_pair
      
      # Password - use provided, shared temp password for AD users (only if directory provided), or null for standalone
      admin_password = config.admin_password != null ? config.admin_password : (
        config.join_ad && var.directory_id != null ? var.shared_temp_password : null
      )
      store_passwords_in_secrets_manager = config.store_passwords_in_secrets_manager
      
      # Storage
      volumes = config.volumes
      
      # Active Directory - only if AD integration is enabled
      join_ad = config.join_ad && var.enable_ad_integration
      
      # Tags
      tags = merge(var.tags, config.tags, {
        User = user
        Name = "${var.project_prefix}-${user}-vdi"
      })
    }
  }
}