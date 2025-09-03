locals {
  project_prefix = "cgd"
  environment    = "dev"

  # Single region configuration
  primary_region = "us-east-1"
  kubernetes_version = "1.33"
  unreal_cloud_ddc_version = "1.2.0"
  scylla_instance_type = "i4i.xlarge"

  # Network access
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  # DDC Domain
  ddc_subdomain = "ddc"
  ddc_fully_qualified_domain_name = "${local.primary_region}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"

  # Common tags
  tags = {
    ProjectPrefix = local.project_prefix
    Environment = local.environment
    IaC = "Terraform"
    ModuleBy = "CGD-Toolkit"
  }
}
