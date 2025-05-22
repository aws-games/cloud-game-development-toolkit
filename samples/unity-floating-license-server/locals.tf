data "aws_availability_zones" "available" {
  exclude_zone_ids = ["usw2-lax1-az1", "usw2-lax1-az2", "usw2-hnl1-az1", "usw2-las1-az1", "usw2-den1-az1"]
}
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Environment = "cgd"
    Application = "unity-floating-license-server"
  }
}
