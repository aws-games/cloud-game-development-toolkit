data "aws_availability_zones" "available" {}

locals {
  vpc_cidr_block       = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
  azs                  = slice(data.aws_availability_zones.available.names, 0, 2)
  tags = {
    Project   = "horde-multiregion"
    ManagedBy = "terraform"
  }
}
