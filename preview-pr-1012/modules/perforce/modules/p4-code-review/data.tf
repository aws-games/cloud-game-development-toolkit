data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Get the latest P4 Code Review AMI built by Packer
# Only used if ami_id variable is not provided
data "aws_ami" "p4_code_review" {
  count       = var.ami_id != null ? 0 : 1
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["p4_code_review_ubuntu-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Lookup subnet details to determine availability zone for EBS volume
# EBS volumes must be in the same AZ as the EC2 instance
data "aws_subnet" "instance_subnet" {
  id = var.instance_subnet_id
}
