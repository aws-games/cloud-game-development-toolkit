#data "aws_subnet" "instance_subnet" {
#  id = var.instance_subnet_id
#}

data "aws_subnet" "selected" {
  for_each = { for idx, server in var.server_configuration : server.type => server }
  id       = each.value.subnet_id
}


# Fetching custom Perforce Helix Core AMI
data "aws_ami" "helix_core_ami" {
  most_recent = true
  name_regex  = "p4_al2023-*"
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["p4_al2023-*"]
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
