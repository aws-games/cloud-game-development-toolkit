# Auto-detect current IP
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for current region
data "aws_region" "current" {}

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
