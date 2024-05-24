data "aws_subnet" "instance_subnet" {
  id = var.instance_subnet_id
}

data "aws_ami" "helix_swarm_ami" {
  most_recent = true
  name_regex  = "helix_swarm-*"
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["helix_swarm-*"]
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
