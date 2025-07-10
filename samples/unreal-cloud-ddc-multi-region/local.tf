data "aws_availability_zones" "available_region_1" {
  region           = "us-west-2"
  exclude_zone_ids = ["usw2-lax1-az1", "usw2-lax1-az2", "usw2-hnl1-az1", "usw2-las1-az1", "usw2-den1-az1"]
}

data "aws_availability_zones" "available_region_2" {
  region           = "us-east-2"
  exclude_zone_ids = ["usw2-lax1-az1", "usw2-lax1-az2", "usw2-hnl1-az1", "usw2-las1-az1", "usw2-den1-az1"]
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

  scylla_ips = concat(module.unreal_cloud_ddc_infra_region_1.scylla_ips, module.unreal_cloud_ddc_infra_region_2.scylla_ips)

  tags = {
    Environment = "cgd"
    Application = "unreal-cloud-ddc"
  }
}
