data "aws_availability_zones" "available" {
  exclude_zone_ids = ["usw2-lax1-az1", "usw2-lax1-az2", "usw2-hnl1-az1", "usw2-las1-az1", "usw2-den1-az1"]
}

data "aws_region" "current" {}

locals {
  project_prefix = "cgd"
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # Networking
  public_subnet_cidrs  = ["192.168.2.0/24", "192.168.3.0/24"]
  private_subnet_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]

  tags = {
    Environment = "dev"
    Application = "unreal-cloud-ddc"
  }
}
