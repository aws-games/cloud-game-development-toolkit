data "aws_subnet" "instance_subnet" {
  id = var.instance_subnet_id
}

# Fetching custom Perforce Helix Core AMI
data "aws_ami" "helix_core_ami" {
  most_recent = true
  name_regex  = "p4_rocky_linux-*"
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["p4_rocky_linux-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
