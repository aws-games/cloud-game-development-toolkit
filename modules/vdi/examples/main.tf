# VDI Example with Managed Microsoft AD
# This example creates both the AD directory and VDI instances

# VDI Module Call
module "vdi" {
  source = "../"

  # General Configuration
  project_prefix = var.project_prefix
  environment    = var.environment

  # Networking - Use the VPC and subnets created in vpc.tf
  vpc_id  = aws_vpc.vdi_vpc.id
  subnets = aws_subnet.vdi_public_subnet[*].id

  # Individual User Configurations
  vdi_config = {
    # Example User 1 - Developer with AD
    JohnSmith = {
      # Compute
      ami           = null # Uses auto-discovered AMI
      instance_type = var.instance_type

      # Networking
      availability_zone           = data.aws_availability_zones.available.names[0]
      subnet_id                   = aws_subnet.vdi_public_subnet[0].id
      associate_public_ip_address = var.associate_public_ip_address

      # Security
      create_default_security_groups = true
      allowed_cidr_blocks            = ["0.0.0.0/0"] # Open for example - restrict in production

      # Key Pair and Password Management
      create_key_pair                    = var.create_key_pair
      admin_password                     = var.admin_password
      store_passwords_in_secrets_manager = var.store_passwords_in_secrets_manager

      # Storage - Storage for dev
      volumes = {
        Root = {
          capacity = 256
          type     = "gp3"
          iops     = 5000
        }

        Assets = {
          capacity = 512
          type     = "gp3"
        }
      }

      # Active Directory (always enabled in this example)
      join_ad = true

      # Tags for user identification and AD creation
      tags = merge(local.common_tags, {
        # User information for AD creation (when join_ad = true)
        given_name  = "John"
        family_name = "Smith"
        email       = "john.smith@company.com"
        role        = "Senior Developer"
      })
    }

    SarahJohnson = {
      # Compute
      ami           = null
      instance_type = "g4dn.4xlarge" # More powerful for design work

      # Networking
      availability_zone           = data.aws_availability_zones.available.names[0]
      subnet_id                   = aws_subnet.vdi_public_subnet[0].id
      associate_public_ip_address = true

      # Security
      create_default_security_groups = true
      allowed_cidr_blocks            = ["10.0.0.0/8"]

      # Key Pair and Password Management
      create_key_pair                    = true
      admin_password                     = var.admin_password  # Use shared temp password
      store_passwords_in_secrets_manager = true

      # Storage - More storage for design files
      volumes = {
        Root = {
          capacity = 256
          type     = "gp3"
          iops     = 5000
        }
        Projects = {
          capacity = 512
          type     = "gp3"
        }
        Assets = {
          capacity = 1024
          type     = "gp3"
        }
      }

      # Active Directory (always enabled in this example)
      join_ad = true

      # Tags for user identification and AD creation
      tags = {
        # User information for AD creation (when join_ad = true)
        given_name  = "Sarah"
        family_name = "Johnson"
        email       = "sarah.johnson@company.com"
        role        = "Senior Designer"
      }
    }
  }

  # Active Directory Configuration (always enabled in this example)
  enable_ad_integration = true
  directory_id         = aws_directory_service_directory.managed_ad.id
  directory_name       = var.directory_name
  dns_ip_addresses     = aws_directory_service_directory.managed_ad.dns_ip_addresses
  ad_admin_password    = var.directory_admin_password
  shared_temp_password = var.admin_password # Use admin_password as shared temporary password

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