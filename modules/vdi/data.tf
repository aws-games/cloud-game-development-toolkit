# Data sources for existing infrastructure
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source to get the user's public IP address
data "http" "user_public_ip" {
  url = "https://ipv4.icanhazip.com"
}

# Data source to find the AMI created by the packer template
data "aws_ami" "windows_server_2025_vdi" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_prefix}-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
