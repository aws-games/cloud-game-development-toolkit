data "aws_ami" "unity_license_server" {
  name_regex  = var.unity_ami_prefix
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [var.unity_ami_prefix]
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
