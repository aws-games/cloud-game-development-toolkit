data "aws_caller_identity" "current" {}

# VPC data source for CIDR block (used in security group rules)
data "aws_vpc" "main" {
  region = var.region
  id     = var.vpc_id
}

# # Fetch official Scylla AMI
data "aws_ami" "scylla_ami" {
  most_recent = true
  owners      = ["797456418907", "158855661827"]
  filter {
    name   = "name"
    values = [var.scylla_ami_name]
  }
  filter {
    name   = "architecture"
    values = [var.scylla_architecture]
  }
  region = var.region
}

# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  region      = var.region
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
  filter {
    name   = "architecture"
    values = [var.scylla_architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


