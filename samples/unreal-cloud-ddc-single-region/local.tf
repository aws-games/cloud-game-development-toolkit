data "aws_availability_zones" "available" {
  exclude_zone_ids = ["usw2-lax1-az1", "usw2-lax1-az2", "usw2-hnl1-az1", "usw2-las1-az1", "usw2-den1-az1"]
}

data "aws_region" "current" {}

data "aws_ecr_authorization_token" "token" {}

data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Environment = "cgd"
    Application = "unreal-cloud-ddc"
  }
}
