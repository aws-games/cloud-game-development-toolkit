# Data sources for existing infrastructure
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for availability zones (used for fallback AZ selection)
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source to find the AMI created by the packer template
data "aws_ami" "windows_server_2025" {
  count       = length([for user, config in var.vdi_config : user if config.ami == null]) > 0 ? 1 : 0
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
