# VDI Module - Private Connectivity Example
# Private access via AWS Client VPN with Secrets Manager authentication

module "vdi" {
  # Update source path based on your setup:
  # Local: "./path/to/modules/vdi" (relative path to where you put the module)
  # Remote: "github.com/aws-games/cloud-game-development-toolkit//modules/vdi?ref=main"
  source = "../../"

  # Core configuration
  project_prefix = local.project_prefix
  region         = data.aws_region.current.id
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # Create Client VPN infrastructure
  create_client_vpn = true

  # Client VPN configuration - avoid CIDR overlap with local network
  client_vpn_config = {
    client_cidr_block = "10.100.0.0/16" # Avoid overlapping with local networks, especially 192.168.x.x/24 home networks
  }

  # 1. PRESETS - Configuration blueprints with different AMIs for different roles
  presets = {
    # Game developer workstation with pre-built UE + Visual Studio
    ue-gamedev-workstation = {
      instance_type = "g4dn.4xlarge"                     # 16 vCPU, 64GB RAM, T4 GPU - optimal for UE compilation + rendering
      ami           = data.aws_ami.vdi_ue_gamedev_ami.id # UE GameDev AMI with VS2022 + Epic Launcher
      gpu_enabled   = true
      volumes = {
        Root = {
          capacity  = 300 # Windows + VS2022 + UE5 + tools (automatically gets C:)
          type      = "gp3"
          iops      = 3000
          encrypted = true
        }
        Projects = {
          capacity  = 2000 # UE projects, assets, builds (2TB)
          type      = "gp3"
          iops      = 3000
          encrypted = true
        }
      }
      # Minimal packages - most tools already in UE GameDev AMI
      software_packages = ["vscode", "notepadplusplus"]
    }

    # DevOps workstation with comprehensive toolchain
    devops-workstation = {
      instance_type = "g4dn.xlarge"                       # 4 vCPU, 16GB RAM, T4 GPU - good for general VDI + software installs
      ami           = data.aws_ami.vdi_lightweight_ami.id # Lightweight AMI for runtime customization
      gpu_enabled   = true
      volumes = {
        Root = {
          capacity  = 200 # Room for user-installed software (automatically gets C:)
          type      = "gp3"
          iops      = 3000
          encrypted = true
        }
        UserData = {
          capacity  = 500 # Large workspace for user files and applications
          type      = "gp3"
          iops      = 3000
          encrypted = true
        }
      }
      # Full DevOps toolchain
      software_packages = [
        "vscode", "terraform", "kubernetes-cli", "docker-desktop",
        "postman", "checkov", "7zip"
      ]
    }
  }

  # 2. WORKSTATIONS - Showing three configuration patterns
  workstations = {
    # Pattern 1: Pure template-based (Naruto - Game Developer)
    "vdi-001" = {
      preset_key          = "ue-gamedev-workstation" # Uses template exactly as defined
      assigned_user       = "naruto-uzumaki"         # User assigned to this workstation
      subnet_id           = aws_subnet.vdi_private_subnet.id
      security_groups     = [aws_security_group.vdi_private_sg.id]
      allowed_cidr_blocks = ["10.0.0.0/16"]
    }

    # Pattern 2: Template with overrides (Sasuke - DevOps Engineer)
    "vdi-002" = {
      preset_key          = "devops-workstation" # Uses template as base
      assigned_user       = "sasuke-uchiha"      # User assigned to this workstation
      subnet_id           = aws_subnet.vdi_private_subnet.id
      security_groups     = [aws_security_group.vdi_private_sg.id]
      allowed_cidr_blocks = ["10.0.0.0/16"]
      # Override: Add extra packages beyond template
      software_packages = [
        "vscode", "terraform", "kubernetes-cli", "docker-desktop",
        "postman", "checkov", "7zip",
        "git", "notepadplusplus" # Additional packages for this workstation
      ]
    }

    # Pattern 3: Direct configuration (Boruto - Junior Developer)
    "vdi-003" = {
      # No preset_key - direct configuration
      assigned_user = "boruto-uzumaki" # User assigned to this workstation
      ami           = data.aws_ami.vdi_lightweight_ami.id
      instance_type = "g4dn.xlarge" # Smaller instance for junior dev
      gpu_enabled   = true
      volumes = {
        Root = {
          capacity  = 150 # Smaller root volume (automatically gets C:)
          type      = "gp3"
          iops      = 3000
          encrypted = true
        }
        Learning = {
          capacity  = 200 # Learning materials and projects
          type      = "gp3"
          iops      = 3000
          encrypted = true
        }
      }
      # Basic learning tools
      software_packages = ["vscode", "git", "notepadplusplus"]

      subnet_id           = aws_subnet.vdi_private_subnet.id
      security_groups     = [aws_security_group.vdi_private_sg.id]
      allowed_cidr_blocks = ["10.0.0.0/16"]
    }
  }

  # 3. LOCAL USERS - Two personas with private VPN access
  users = {
    "vdiadmin" = {
      given_name     = "VDI"
      family_name    = "Administrator"
      email          = "admin@example.com"
      type           = "fleet_administrator" # Fleet management - admin on ALL workstations
      use_client_vpn = true                  # VPN access - gets .ovpn file
    }
    # Game Developer - UE development, needs high-performance workstation
    "naruto-uzumaki" = {
      given_name     = "Naruto"
      family_name    = "Uzumaki"
      email          = "naruto@example.com"
      type           = "administrator" # Admin on assigned workstation only
      use_client_vpn = true            # VPN access - gets .ovpn file
    }
    # DevOps Engineer - Infrastructure, CI/CD, build systems
    "sasuke-uchiha" = {
      given_name     = "Sasuke"
      family_name    = "Uchiha"
      email          = "sasuke@example.com"
      type           = "administrator" # Admin on assigned workstation only
      use_client_vpn = true            # VPN access - gets .ovpn file
    }
    # Junior Developer - standard user, VPN access for learning
    "boruto-uzumaki" = {
      given_name     = "Boruto"
      family_name    = "Uzumaki"
      email          = "boruto@example.com"
      type           = "user" # Windows Users group - limited privileges
      use_client_vpn = true   # VPN access - gets .ovpn file
    }
  }



  # DCV session management (Windows DCV creates single shared session automatically)

  # Optional features
  enable_centralized_logging = true


  # Software packages now defined per-template or per-workstation (see workstations below)

  tags = merge(local.tags, {
    Example      = "private-connectivity"
    AuthMethod   = "secrets-manager"
    Connectivity = "client-vpn"
  })
}
