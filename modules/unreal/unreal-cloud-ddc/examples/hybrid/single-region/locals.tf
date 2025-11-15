locals {
  # General
  project_prefix = "cgd"
  name           = "unreal-cloud-ddc"
  environment    = "dev"
  name_prefix    = "${local.project_prefix}-${local.name}-${local.environment}"
  region = "us-east-1"

  # Network access
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  # DDC Domain
  ddc_subdomain = "ddc"
  ddc_fully_qualified_domain_name = "${local.region}.${local.environment}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"

  # Common tags - standardized with CGD Toolkit patterns
  tags = {
    # Project identification
    ProjectPrefix = local.project_prefix
    Environment   = local.environment

    # Infrastructure as Code metadata
    IaC        = "Terraform"
    ModuleBy   = "CGD-Toolkit"
    ModuleName = "unreal-cloud-ddc"

    # Deployment context
    DeployedBy = "terraform-example"
    Region     = local.region
  }
}
