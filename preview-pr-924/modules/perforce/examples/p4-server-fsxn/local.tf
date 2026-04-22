data "aws_availability_zones" "available" {}

locals {
  project_prefix = "cgd"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)

  # Subdomains
  perforce_subdomain = "perforce"

  # P4 Server Domain
  p4_server_fully_qualified_domain_name = "${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"

  # VPC Configuration
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

  tags = {
    environment = "dev"
  }
}
