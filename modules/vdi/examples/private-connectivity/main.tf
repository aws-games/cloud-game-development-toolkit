# VDI Module - Private Connectivity Example
# Private access via AWS Client VPN with Secrets Manager authentication

# Data source to find latest VDI lightweight AMI (for general users)
data "aws_ami" "vdi_lightweight_ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["vdi-lightweight-windows-server-2025-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Data source to find latest UE GameDev AMI (for game developers)
data "aws_ami" "vdi_ue_gamedev_ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["vdi-ue-gamedev-windows-server-2025-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Fallback to AWS base AMI if custom AMIs not found
data "aws_ami" "windows_server_2025_base" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2025-English-Full-Base-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

module "vdi" {
  source = "../../"

  # Core configuration
  project_prefix = local.project_prefix
  region         = data.aws_region.current.id
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # Enable private connectivity infrastructure
  enable_private_connectivity = true

  # 1. TEMPLATES - Configuration blueprints with different AMIs for different roles
  templates = {
    # Game developer workstation with pre-built UE + Visual Studio
    ue-gamedev-workstation = {
      instance_type = "g4dn.4xlarge"  # 16 vCPU, 64GB RAM, T4 GPU - optimal for UE compilation + rendering
      ami           = data.aws_ami.vdi_ue_gamedev_ami.id  # UE GameDev AMI with VS2022 + Epic Launcher
      gpu_enabled   = true
      volumes = {
        Root = {
          capacity      = 300  # Windows + VS2022 + UE5 + tools
          type          = "gp3"
          windows_drive = "C:"
          iops          = 3000
          encrypted     = true
        }
        Projects = {
          capacity      = 2000  # UE projects, assets, builds (2TB)
          type          = "gp3"
          windows_drive = "D:"
          iops          = 3000
          encrypted     = true
        }
      }
    }
    
    # General VDI workstation with GPU acceleration
    general-vdi-workstation = {
      instance_type = "g4dn.xlarge"  # 4 vCPU, 16GB RAM, T4 GPU - good for general VDI + software installs
      ami           = data.aws_ami.vdi_lightweight_ami.id  # Lightweight AMI for runtime customization
      gpu_enabled   = true
      volumes = {
        Root = {
          capacity      = 200  # Room for user-installed software
          type          = "gp3"
          windows_drive = "C:"
          iops          = 3000
          encrypted     = true
        }
        UserData = {
          capacity      = 500  # Large workspace for user files and applications
          type          = "gp3"
          windows_drive = "D:"
          iops          = 3000
          encrypted     = true
        }
      }
    }
  }

  # 2. WORKSTATIONS - Physical infrastructure with different templates
  workstations = {
    "vdi-001" = {
      template_key      = "ue-gamedev-workstation"  # UE GameDev AMI with pre-installed tools
      subnet_id         = aws_subnet.vdi_private_subnet.id
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_private_sg.id]
      # No public access - only via Client VPN
      allowed_cidr_blocks = ["10.0.0.0/16"]
    }

    "vdi-002" = {
      template_key      = "general-vdi-workstation"  # General VDI with GPU acceleration
      subnet_id         = aws_subnet.vdi_private_subnet.id
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_private_sg.id]
      allowed_cidr_blocks = ["10.0.0.0/16"]
    }
  }

  # 3. LOCAL USERS - Individual identity with Windows group types
  users = {
    "vdiadmin" = {
      given_name  = "VDI"
      family_name = "Administrator"
      email       = "admin@company.com"
      type        = "administrator"  # Maps to Windows Administrators group
    }
    "naruto-uzumaki" = {
      given_name  = "Naruto"
      family_name = "Uzumaki"
      email       = "naruto@konoha.com"
      type        = "user"  # Maps to Windows Users group (standard access)
    }
    "sasuke-uchiha" = {
      given_name  = "Sasuke"
      family_name = "Uchiha"
      email       = "sasuke@konoha.com"
      type        = "user"  # Maps to Windows Users group (standard access)
    }
  }

  # 4. WORKSTATION ASSIGNMENTS - Workstation to user mapping
  workstation_assignments = {
    "vdi-001" = {
      user = "naruto-uzumaki"    # References users{} key
    }
    "vdi-002" = {
      user = "sasuke-uchiha"  # References users{} key
    }
  }

  # DCV session management (Windows DCV creates single shared session automatically)

  # Optional features
  enable_centralized_logging = true

  tags = merge(local.tags, {
    Example = "private-connectivity"
    AuthMethod = "secrets-manager"
    Connectivity = "client-vpn"
  })
}
