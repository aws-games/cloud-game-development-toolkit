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
  name_regex  = "al2023-ami-2023.5.*"
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.5.*"]
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
