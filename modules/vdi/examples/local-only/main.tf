# VDI Module - Local-Only Example
# Local users with Secrets Manager authentication, no Active Directory

module "vdi" {
  source = "../../"

  # Core configuration
  project_prefix = local.project_prefix
  region         = data.aws_region.current.id
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # 1. TEMPLATES - Configuration blueprints
  templates = {
    developer-workstation = {
      instance_type = "g4dn.2xlarge"
      ami           = "ami-0958f6fd69d32dcce"  # CGD Toolkit lightweight AMI - working SSM/PowerShell modules
      gpu_enabled   = true
      software_packages = ["chocolatey", "git"]  # Base packages for all developer workstations
      volumes = {
        Root = {
          capacity      = 100
          type          = "gp3"
          windows_drive = "C:"
          iops          = 3000
          encrypted     = true
        }
        Projects = {
          capacity      = 500
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
    "vdi-001" = {
      template_key      = "developer-workstation"  # Inherits: chocolatey, git, volumes, instance_type, etc.
      subnet_id         = aws_subnet.vdi_subnet.id
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_sg.id]

      # Add additional software to template packages
      software_packages_additions = ["visual-studio-2022"]  # Final: chocolatey, git, visual-studio-2022

      allowed_cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    }

    "vdi-002" = {
      template_key      = "developer-workstation"  # Inherits: chocolatey, git, volumes, instance_type, etc.
      subnet_id         = aws_subnet.vdi_subnet.id
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_sg.id]

      # Add different software for this workstation
      software_packages_additions = ["perforce", "unreal-engine-5.3"]  # Final: chocolatey, git, perforce, unreal-engine-5.3

      # Exclude some template packages if needed
      software_packages_exclusions = ["git"]  # Final: chocolatey, perforce, unreal-engine-5.3

      allowed_cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    }
  }

  # 3. LOCAL USERS - Individual identity (Secrets Manager)
  users = {
    "john-doe" = {
      given_name  = "John"
      family_name = "Doe"
      email       = "john@company.com"
    }
    "jane-smith" = {
      given_name  = "Jane"
      family_name = "Smith"
      email       = "jane@company.com"
    }
  }

  # 4. AD USERS - Empty for local-only setup
  ad_users = {}

  # 5. AD GROUPS - Empty for local-only setup
  ad_groups = {}

  # 6. WORKSTATION ASSIGNMENTS - Workstation to user mapping
  workstation_assignments = {
    "vdi-001" = {
      user        = "john-doe"    # References users{} key
      user_source = "local"       # Uses Secrets Manager authentication
    }
    "vdi-002" = {
      user        = "jane-smith"  # References users{} key
      user_source = "local"       # Uses Secrets Manager authentication
    }
  }

  # Authentication configuration
  enable_ad_integration = false  # No Active Directory - uses local users with Secrets Manager

  # DCV session management (Windows DCV creates single shared session automatically)

  # Optional features
  enable_centralized_logging = true

  tags = merge(local.tags, {
    Example = "local-only"
    AuthMethod = "secrets-manager"
  })
}
