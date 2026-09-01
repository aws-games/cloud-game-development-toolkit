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

# Data source to find specific VDI lightweight AMI version (for general users)
# PREREQUISITE: You must build this AMI using:
# cd assets/packer/virtual-workstations/lightweight/
# packer build windows-server-2025-lightweight.pkr.hcl
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

# Data source to find specific UE GameDev AMI version (for game developers)
# PREREQUISITE: You must build this AMI using:
# cd assets/packer/virtual-workstations/ue-gamedev/
# packer build windows-server-2025-ue-gamedev.pkr.hcl
data "aws_ami" "vdi_ue_gamedev_ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["vdi-ue-gamedev-windows-server-2025-*"] # Pinned to specific version
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
