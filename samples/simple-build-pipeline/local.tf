data "aws_availability_zones" "available" {}

locals {
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

  tags = {
    environment = "build"
  }
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}
