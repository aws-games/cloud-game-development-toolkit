# VDI Example with Managed Microsoft AD
# This example creates both the AD directory and VDI instances

# VDI Module Call
module "vdi" {
  source = "../.."

  # Add extracted user IPs
  user_public_ips = local.user_public_ips
  
  # General Configuration
  project_prefix = var.project_prefix
  environment    = var.environment

  # Networking - Use the VPC and subnets created in vpc.tf
  vpc_id  = aws_vpc.vdi_vpc.id
  subnets = aws_subnet.vdi_public_subnet[*].id

  # Dynamic VDI configuration - automatically generated from vdi_user_data in locals.tf
  # Users, passwords, secrets, and AD accounts are all created automatically
  vdi_config = {
    for username, user_data in local.vdi_user_data : username => merge(
      local.vdi_user_defaults,
      {
        # User-specific overrides
        instance_type = lookup(user_data, "instance_type", var.instance_type)
        volumes       = user_data.volumes

        # Dynamic tags from user data
        tags = merge(local.common_tags, {
          given_name  = user_data.given_name
          family_name = user_data.family_name
          email       = user_data.email
          role        = user_data.role
        })
      }
    )
  }

  # Active Directory Configuration (always enabled in this example)
  enable_ad_integration = true
  directory_id          = aws_directory_service_directory.managed_ad.id
  directory_name        = local.directory_name
  dns_ip_addresses      = aws_directory_service_directory.managed_ad.dns_ip_addresses
  ad_admin_password     = local.ad_admin_password

  # Enable automatic AD user management and DCV configuration
  manage_ad_users = true

  # Individual AD user passwords
  individual_user_passwords = {
    for user, password in random_password.ad_user_passwords : user => password.result
  }

  # Tags
  tags = local.common_tags

  # Ensure directory is created, DS Data access enabled, and ready before VDI deployment
  depends_on = [
    aws_directory_service_directory.managed_ad,
    null_resource.enable_ds_data_access,
    time_sleep.wait_for_directory_ready
  ]
}

# Wait for directory to be ready before creating VDI resources
resource "time_sleep" "wait_for_directory_ready" {
  create_duration = "2m" # Wait 2 minutes for directory to be fully ready

  depends_on = [aws_directory_service_directory.managed_ad]
}
