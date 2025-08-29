data "aws_availability_zones" "available" {}

locals {
  project_prefix = "cgd"
  name_prefix    = "${local.project_prefix}-unreal-cloud-ddc"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)

  # Region Configuration
  region = {
    name  = "us-east-1"
    alias = "primary"
  }

  # Application Configuration
  ddc_namespace = "unreal-cloud-ddc"
  environment   = "dev"
  
  # Subdomains
  ddc_subdomain        = "ddc"
  monitoring_subdomain = "monitoring"

  # DDC Domain
  ddc_fully_qualified_domain_name = "${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"

  # Monitoring Domain
  monitoring_fully_qualified_domain_name = "${local.monitoring_subdomain}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"

  # VPC Configuration
  vpc_cidr             = "192.168.0.0/16"
  public_subnet_cidrs  = ["192.168.2.0/24", "192.168.3.0/24"]
  private_subnet_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]

  tags = {
    Environment = "dev"
    Application = "unreal-cloud-ddc"
  }
}