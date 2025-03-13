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
