# Lookup of subnet that module creates
data "aws_subnet" "instance_subnet" {
  id = var.instance_subnet_id
}

# Conditionally fetch exist P4 Server AMI that unless using the auto-generated AMI
data "aws_ami" "existing_server_ami" {
  count       = var.lookup_existing_ami == true ? 1 : 0
  most_recent = true
  name_regex  = "${var.ami_prefix}_*"
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_prefix}_*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = [var.instance_architecture]
  }
}

# Conditionally look up AMI that local-exec will create using Packer
data "aws_ami" "autogen_server_ami" {
  count = var.enable_auto_ami_creation == true ? 1 : 0

  most_recent = true
  name_regex  = "${var.ami_prefix}_*"
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_prefix}_*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = [var.instance_architecture]
  }

  depends_on = [null_resource.packer_template]
}
