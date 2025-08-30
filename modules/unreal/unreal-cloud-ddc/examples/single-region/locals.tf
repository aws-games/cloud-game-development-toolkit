locals {
  project_prefix = "cgd"
  environment    = "dev"
  region         = "us-east-1"
  
  # Kubernetes version
  kubernetes_version = "1.33"
  
  # Common configuration
  unreal_cloud_ddc_version = "1.2.0"
  scylla_instance_type = "i4i.xlarge"
  scylla_monitoring_instance_type = "t3.xlarge"
  
  # Network access
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  
  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  
  # Subdomains
  ddc_subdomain = "ddc"
  monitoring_subdomain = "monitoring"
  
  # DDC Domain
  ddc_fully_qualified_domain_name = "${local.region}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  
  # Monitoring Domain
  monitoring_fully_qualified_domain_name = "${local.region}.${local.monitoring_subdomain}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  
  # Amazon Certificate Manager (ACM)
  certificate_arn = aws_acm_certificate.ddc.arn
  
  # Common tags
  tags = {
    ProjectPrefix = local.project_prefix
    Environment   = local.environment
    IaC          = "Terraform"
    ModuleBy     = "CGD-Toolkit"
  }
}