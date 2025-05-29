data "aws_availability_zones" "available_us_west_2" {
  region           = "us-west-2"
  exclude_zone_ids = ["usw2-lax1-az1", "usw2-lax1-az2", "usw2-hnl1-az1", "usw2-las1-az1", "usw2-den1-az1"]
}

data "aws_availability_zones" "available_us_east_2" {
  region           = "us-east-2"
  exclude_zone_ids = ["usw2-lax1-az1", "usw2-lax1-az2", "usw2-hnl1-az1", "usw2-las1-az1", "usw2-den1-az1"]
}

data "aws_region" "us_west_2" {
  region = "us-west-2"
}

data "aws_region" "us_east_2" {
  region = "us-east-2"
}

data "aws_ecr_authorization_token" "token_us_west_2" {
  region = "us-west-2"
}

data "aws_ecr_authorization_token" "token_us_east_2" {
  region = "us-east-2"
}

data "aws_caller_identity" "current" {}

locals {
  azs_us_west_2 = slice(data.aws_availability_zones.available_us_west_2.names, 0, 2)
  azs_us_east_2 = slice(data.aws_availability_zones.available_us_east_2.names, 0, 2)

  tags = {
    Environment = "cgd"
    Application = "unreal-cloud-ddc"
  }

  existing_security_groups_us_west_2 = var.allow_my_ip ? concat(var.existing_security_groups_us_west_2, [aws_security_group.unreal_ddc_load_balancer_access_security_group_us_west_2.id]) : var.existing_security_groups_us_west_2
  existing_security_groups_us_east_2 = var.allow_my_ip ? concat(var.existing_security_groups_us_east_2, [aws_security_group.unreal_ddc_load_balancer_access_security_group_us_east_2.id]) : var.existing_security_groups_us_east_2
}
