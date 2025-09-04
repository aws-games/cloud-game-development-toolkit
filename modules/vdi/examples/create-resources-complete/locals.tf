# Local variables for the VDI example

locals {
  name_prefix = "${var.project_prefix}-${var.name}"

  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = "VDI-Example"
    Owner       = "DevOps-Team"
    Purpose     = "Development-Workstation"
  })

  # ADMIN SECTION: VDI User Management
  # For user management/ creation and instance configuration guide, see README.md
  vdi_user_data = {
    ExampleUser = {
      given_name    = "Example"
      family_name   = "User"
      email         = "example.user@company.com"
      role          = "Senior Developer"
      public_ip     = "10.20.30.40"     # Replace with user public IP ##Required for connectivity through security groups##
      instance_type = var.instance_type # g4dn.2xlarge
      volumes = {
        Root   = { capacity = 256, type = "gp3", iops = 5000 }
        Assets = { capacity = 512, type = "gp3" }
      }
    }

    ### ExampleUser#2 ###

    ### ExampleUser#3 ###
  }
  # Extract user list dynamically from user data
  vdi_users = toset(keys(local.vdi_user_data))

  # Default VDI user configuration (reduces duplication)
  vdi_user_defaults = {
    ami               = null
    availability_zone = data.aws_availability_zones.available.names[0]
    subnet_id         = aws_subnet.vdi_public_subnet[0].id
    # associate_public_ip_address, create_default_security_groups, create_key_pair always true in VDI module
    allowed_cidr_blocks = [aws_vpc.vdi_vpc.cidr_block]
    join_ad             = true
  }

  # Extract user public IPs from user data
  user_public_ips = {
    for username, user_data in local.vdi_user_data : username => user_data.public_ip
    if lookup(user_data, "public_ip", null) != null
  }

  # Validation: directory_name is always required in this example
  validate_directory_name = var.directory_name != null && var.directory_name != ""
}

# Validation resource
resource "null_resource" "validate_directory_name" {
  count = local.validate_directory_name ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: directory_name is required in this example. Please set directory_name in your terraform.tfvars file.' && exit 1"
  }
}

# Shared password configuration for AD compliance
locals {
  ad_password_config = {
    length      = 16
    special     = true
    upper       = true
    lower       = true
    numeric     = true
    min_upper   = 1
    min_lower   = 1
    min_numeric = 1
    min_special = 1
  }
}

# Generate secure AD admin password
resource "random_password" "ad_admin_password" {
  length      = local.ad_password_config.length
  special     = local.ad_password_config.special
  upper       = local.ad_password_config.upper
  lower       = local.ad_password_config.lower
  numeric     = local.ad_password_config.numeric
  min_upper   = local.ad_password_config.min_upper
  min_lower   = local.ad_password_config.min_lower
  min_numeric = local.ad_password_config.min_numeric
  min_special = local.ad_password_config.min_special
}

# Generate unique AD passwords for each VDI user
resource "random_password" "ad_user_passwords" {
  for_each = local.vdi_users

  length      = local.ad_password_config.length
  special     = local.ad_password_config.special
  upper       = local.ad_password_config.upper
  lower       = local.ad_password_config.lower
  numeric     = local.ad_password_config.numeric
  min_upper   = local.ad_password_config.min_upper
  min_lower   = local.ad_password_config.min_lower
  min_numeric = local.ad_password_config.min_numeric
  min_special = local.ad_password_config.min_special

  # Rotate password when needed
  keepers = {
    user = each.key
  }
}

# ========================================
# CONSOLIDATED SECRETS MANAGEMENT (3 secrets total)
# Reduces from 3N+1 secrets to 3 secrets regardless of user count
# ========================================

# Generate unique deployment identifier for secret naming
resource "random_id" "deployment_id" {
  byte_length = 4
}

# SECRET 1: VDI User Credentials (All users in one JSON secret)
resource "aws_secretsmanager_secret" "vdi_user_credentials" {
  # checkov:skip=CKV_AWS_149:KMS CMK encryption not required for VDI user credentials in example environment
  # checkov:skip=CKV2_AWS_57:Automatic rotation not suitable for VDI user passwords requiring manual management
  name                    = "${local.name_prefix}-user-credentials-${random_id.deployment_id.hex}"
  description             = "Consolidated VDI user credentials including AD passwords and private keys"
  recovery_window_in_days = 7
  tags = merge(local.common_tags, {
    SecretType = "UserCredentials"
    UserCount  = length(local.vdi_users)
  })
}

resource "aws_secretsmanager_secret_version" "vdi_user_credentials" {
  secret_id = aws_secretsmanager_secret.vdi_user_credentials.id
  secret_string = jsonencode(merge(
    # AD Login (full domain\username format)
    {
      for user in local.vdi_users : "${user}_ad_login" => "${local.directory_name}\\${lower(user)}"
    },
    # AD Passwords
    {
      for user in local.vdi_users : "${user}_ad_password" => random_password.ad_user_passwords[user].result
    },
    # Private Keys
    {
      for user in local.vdi_users : "${user}_private_key" => module.vdi.private_keys[user]
    }
  ))
}

# SECRET 2: VDI Admin Credentials (AD admin + deployment metadata)
resource "aws_secretsmanager_secret" "vdi_admin_credentials" {
  # checkov:skip=CKV_AWS_149:KMS CMK encryption not required for VDI user credentials in example environment
  # checkov:skip=CKV2_AWS_57:Automatic rotation not suitable for VDI user passwords requiring manual management
  name                    = "${local.name_prefix}-admin-credentials-${random_id.deployment_id.hex}"
  description             = "VDI deployment admin credentials and configuration"
  recovery_window_in_days = 7
  tags = merge(local.common_tags, {
    SecretType = "AdminCredentials"
  })
}

resource "aws_secretsmanager_secret_version" "vdi_admin_credentials" {
  secret_id = aws_secretsmanager_secret.vdi_admin_credentials.id
  secret_string = jsonencode({
    ad_admin_password = random_password.ad_admin_password.result
    directory_name    = local.directory_name
    directory_id      = aws_directory_service_directory.managed_ad.id
  })
}

########################################
# REQUIRED VARIABLES
########################################

locals {
  # Managed Microsoft AD domain name (REQUIRED)
  directory_name = "corp.example.company.com"

  # Use generated passwords
  ad_admin_password = var.directory_admin_password != null ? var.directory_admin_password : random_password.ad_admin_password.result

  # # Optional: Domain name for DNS record
  # domain_name = "example.company.com"
}
