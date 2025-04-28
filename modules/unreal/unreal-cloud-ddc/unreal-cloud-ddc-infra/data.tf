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
}

# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
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
