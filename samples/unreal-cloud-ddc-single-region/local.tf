data "aws_availability_zones" "available" {
  region = data.aws_region.current
  # Filter for standard AZs only
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_region" "current" {}

data "aws_ecr_authorization_token" "token" {}

data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  vpc_cidr              = "192.168.0.0/16"
  private_subnets_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]
  public_subnets_cidrs  = ["192.168.2.0/24", "192.168.3.0/24"]

  nvme_managed_node_instance_type   = "i3en.xlarge"
  worker_managed_node_instance_type = "c6i.large"
  system_managed_node_instance_type = "m7i.large"

  scylla_ami_name      = "ScyllaDB 6.2.1"
  scylla_architecture  = "x86_64"
  scylla_instance_type = "i4i.xlarge"


  tags = {
    Environment = "cgd"
    Application = "unreal-cloud-ddc"
  }
}
