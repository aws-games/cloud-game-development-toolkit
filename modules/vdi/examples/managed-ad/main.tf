# VDI Module - Managed AD Example
# Active Directory users with domain joining and group management

module "vdi" {
  source = "../../"

  # Core configuration
  project_prefix = local.project_prefix
  region         = data.aws_region.current.id
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # 1. TEMPLATES - Configuration blueprints
  templates = {
    ad-workstation = {
      instance_type = "g4dn.2xlarge"
      ami           = null  # Use data source auto-discovery
      gpu_enabled   = true
      software_packages = ["chocolatey", "git"]
      volumes = {
        Root = {
          capacity      = 100
          type          = "gp3"
          windows_drive = "C:"
          iops          = 3000
          encrypted     = true
        }
        Projects = {
          capacity      = 1000
          type          = "gp3"
          windows_drive = "D:"
          iops          = 3000
          encrypted     = true
        }
      }
    }
  }

  # 2. WORKSTATIONS - Physical infrastructure
  workstations = {
    "jane-workstation" = {
      template_key      = "ad-workstation"
      subnet_id         = aws_subnet.vdi_subnet.id
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_sg.id]
      allowed_cidr_blocks = ["10.0.0.0/16"]
    }
    
    "bob-workstation" = {
      template_key      = "ad-workstation"
      subnet_id         = aws_subnet.vdi_subnet.id
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_sg.id]
      allowed_cidr_blocks = ["10.0.0.0/16"]
    }
  }

  # 3. LOCAL USERS - Empty for AD-only setup
  users = {}

  # 4. AD USERS - Active Directory user accounts
  ad_users = {
    "jane-smith" = {
      given_name  = "Jane"
      family_name = "Smith"
      email       = "jane@company.com"
    }
    "bob-jones" = {
      given_name  = "Bob"
      family_name = "Jones"
      email       = "bob@company.com"
    }
  }

  # 5. AD GROUPS - Empty for this example
  ad_groups = {}

  # 6. WORKSTATION ASSIGNMENTS - Workstation to user mapping
  workstation_assignments = {
    "jane-workstation" = {
      user        = "jane-smith"
      user_source = "ad"
    }
    "bob-workstation" = {
      user        = "bob-jones"
      user_source = "ad"
    }
  }

  # Active Directory configuration
  enable_ad_integration = true
  directory_id          = aws_directory_service_directory.managed_ad.id
  directory_name        = local.directory_name
  dns_ip_addresses      = aws_directory_service_directory.managed_ad.dns_ip_addresses
  ad_admin_password     = local.ad_admin_password
  
  # Enable automatic AD user management
  manage_ad_users = true
  
  # Individual AD user passwords
  individual_user_passwords = {
    for user, password in random_password.ad_user_passwords : user => password.result
  }

  # Optional features
  enable_centralized_logging = true

  tags = {
    Example = "managed-ad"
    AuthMethod = "active-directory"
  }
}