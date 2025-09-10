# VDI Module - Private Connectivity Example
# Private VDI workstations accessible via AWS Client VPN

# TODO: Implement AWS Client VPN infrastructure
# This example would provide secure private access to VDI workstations
# without exposing them to the public internet

module "vdi" {
  source = "../../"

  # Core configuration
  project_prefix = local.project_prefix
  region         = data.aws_region.current.id
  environment    = "dev"
  vpc_id         = aws_vpc.vdi_vpc.id

  # Templates - same as local-only but without public access
  templates = {
    developer-workstation = {
      instance_type = "g4dn.2xlarge"
      ami           = "ami-0958f6fd69d32dcce"  # CGD Toolkit lightweight AMI
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
          capacity      = 500
          type          = "gp3"
          windows_drive = "D:"
          iops          = 3000
          encrypted     = true
        }
      }
    }
  }

  # Workstations in private subnets (no public IPs)
  workstations = {
    "vdi-001" = {
      template_key      = "developer-workstation"
      subnet_id         = aws_subnet.vdi_private_subnet.id  # TODO: Create private subnet
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_private_sg.id]  # TODO: Create private SG

      # No public access - only via Client VPN
      # allowed_cidr_blocks = []  # TODO: Remove this variable or make optional
      
      software_packages_additions = ["hello-world"]
    }

    "vdi-002" = {
      template_key      = "developer-workstation"
      subnet_id         = aws_subnet.vdi_private_subnet.id
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = [aws_security_group.vdi_private_sg.id]
    }
  }

  # Local users - same as local-only example
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

  # Workstation assignments
  workstation_assignments = {
    "vdi-001" = {
      user = "john-doe"
    }
    "vdi-002" = {
      user = "jane-smith"
    }
  }

  enable_centralized_logging = true

  tags = merge(local.tags, {
    Example = "private-connectivity"
    AuthMethod = "secrets-manager"
    Connectivity = "client-vpn"
  })
}

# TODO: Add AWS Client VPN infrastructure
# - Client VPN endpoint
# - Client certificates/authentication
# - Route table associations
# - Security group rules for VPN access
# - Private subnets for VDI instances
# - NAT Gateway for outbound internet access

# TODO: Module changes needed:
# - Make allowed_cidr_blocks optional for private deployments
# - Add support for private-only workstations (no public IPs)
# - Consider VPN-specific security group patterns