# VDI Module - External Client VPN Example
# Use your own existing Client VPN endpoint instead of creating one

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Data source for existing Client VPN endpoint
data "aws_ec2_client_vpn_endpoint" "existing" {
  filter {
    name   = "tag:Name"
    values = [var.existing_client_vpn_name]
  }
}

# Data source for existing VPC
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Data source for existing subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

# Data source for existing security groups
data "aws_security_groups" "vdi" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  filter {
    name   = "tag:Name"
    values = ["*vdi*"]
  }
}

# VDI Module - Private connectivity WITHOUT creating Client VPN
module "vdi" {
  source = "../.."

  # Core configuration
  project_prefix = var.project_prefix
  region         = var.region
  vpc_id         = data.aws_vpc.existing.id

  # IMPORTANT: Disable built-in Client VPN creation
  enable_private_connectivity = false

  # Templates
  templates = {
    standard_workstation = {
      instance_type = "g4dn.xlarge"
      volumes = {
        Root = {
          capacity      = 200
          type          = "gp3"
          windows_drive = "C:"
          encrypted     = true
        }
        Data = {
          capacity      = 500
          type          = "gp3"
          windows_drive = "D:"
          encrypted     = true
        }
      }
    }
  }

  # Workstations in private subnets
  workstations = {
    workstation-01 = {
      preset_key        = "standard_workstation"
      subnet_id         = data.aws_subnets.private.ids[0]
      availability_zone = data.aws_availability_zones.available.names[0]
      security_groups   = data.aws_security_groups.vdi.ids
      # Allow access from your Client VPN CIDR
      allowed_cidr_blocks = [var.client_vpn_cidr]
    }
    workstation-02 = {
      preset_key        = "standard_workstation"
      subnet_id         = data.aws_subnets.private.ids[1]
      availability_zone = data.aws_availability_zones.available.names[1]
      security_groups   = data.aws_security_groups.vdi.ids
      allowed_cidr_blocks = [var.client_vpn_cidr]
    }
  }

  # Users - all marked as private connectivity
  users = {
    alice = {
      given_name        = "Alice"
      family_name       = "Smith"
      email             = "alice@company.com"
      type              = "user"
      connectivity_type = "private"  # Uses your existing Client VPN
    }
    bob = {
      given_name        = "Bob"
      family_name       = "Johnson"
      email             = "bob@company.com"
      type              = "user"
      connectivity_type = "private"
    }
  }

  # Assignments
  workstation_assignments = {
    workstation-01 = { user = "alice" }
    workstation-02 = { user = "bob" }
  }

  # Optional: Background software installation
  software_packages = [
    "vscode",
    "terraform",
    "kubernetes-cli"
  ]

  tags = {
    Environment = "production"
    VPN         = "external"
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Optional: Create Route53 records for easy access via your VPN
resource "aws_route53_zone" "vdi_internal" {
  count = var.create_dns_records ? 1 : 0
  
  name = var.internal_domain
  
  vpc {
    vpc_id = data.aws_vpc.existing.id
  }
  
  tags = {
    Name    = "${var.project_prefix}-vdi-internal"
    Purpose = "VDI internal DNS"
  }
}

resource "aws_route53_record" "workstations" {
  for_each = var.create_dns_records ? module.vdi.workstation_instances : {}
  
  zone_id = aws_route53_zone.vdi_internal[0].zone_id
  name    = "${each.key}.${var.internal_domain}"
  type    = "A"
  ttl     = 60
  records = [each.value.private_ip]
}