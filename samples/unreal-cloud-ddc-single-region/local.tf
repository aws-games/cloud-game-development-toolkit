data "aws_availability_zones" "available" {
  exclude_zone_ids = ["usw2-lax1-az1", "usw2-lax1-az2", "usw2-hnl1-az1", "usw2-las1-az1", "usw2-den1-az1"]
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
