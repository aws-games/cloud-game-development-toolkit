data "aws_availability_zones" "available_region_1" {
  region = var.regions[0]

  # Filter for standard AZs only
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_availability_zones" "available_region_2" {
  region = var.regions[1]

  # Filter for standard AZs only
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_region" "region_1" {
  region = var.regions[0]
}

data "aws_region" "region_2" {
  region = var.regions[1]
}

data "aws_ecr_authorization_token" "token_region_1" {
  region = var.regions[0]
}

data "aws_ecr_authorization_token" "token_region_2" {
  region = var.regions[1]
}

data "aws_caller_identity" "current" {}

locals {
  azs_region_1 = slice(data.aws_availability_zones.available_region_1.names, 0, 2)
  azs_region_2 = slice(data.aws_availability_zones.available_region_2.names, 0, 2)

  vpc_cidr_block_region_1        = "192.168.0.0/17"
  private_subnets_cidrs_region_1 = ["192.168.0.0/24", "192.168.1.0/24"]
  public_subnets_cidrs_region_1  = ["192.168.2.0/24", "192.168.3.0/24"]

  vpc_cidr_block_region_2        = "192.168.128.0/17"
  private_subnets_cidrs_region_2 = ["192.168.128.0/24", "192.168.129.0/24"]
  public_subnets_cidrs_region_2  = ["192.168.130.0/24", "192.168.131.0/24"]

  nvme_managed_node_instance_type   = "i3en.xlarge"
  worker_managed_node_instance_type = "c6i.large"
  system_managed_node_instance_type = "m7i.large"

  scylla_ami_name      = "ScyllaDB 6.2.1"
  scylla_architecture  = "x86_64"
  scylla_instance_type = "i4i.xlarge"
  scylla_ips           = concat(module.unreal_cloud_ddc_infra_region_1.scylla_ips, module.unreal_cloud_ddc_infra_region_2.scylla_ips)

  tags = {
    Environment = "cgd"
    Application = "unreal-cloud-ddc"
  }
}
