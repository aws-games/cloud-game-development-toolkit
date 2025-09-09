# Data sources for existing infrastructure
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for availability zones (used for fallback AZ selection)
data "aws_availability_zones" "available" {
  state = "available"
}



# Data source to find the AMI created by the packer template
data "aws_ami" "windows_server_2025" {
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
