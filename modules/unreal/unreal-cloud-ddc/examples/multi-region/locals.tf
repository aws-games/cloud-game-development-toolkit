locals {
  project_prefix = "cgd"
  environment    = "dev"
  
  # Regions
  primary_region = "us-east-1"
  secondary_region = "us-west-2"
  
  # Kubernetes version - ensure consistency across regions
  kubernetes_version = "1.33"
  
  # Common configuration
  unreal_cloud_ddc_version = "1.2.0"
  scylla_instance_type = "i4i.xlarge"
  scylla_monitoring_instance_type = "t3.xlarge"
  
  # Network access
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  
  # VPC Configuration
  vpc_cidr = "10.0.0.0/16"
  azs_primary = ["us-east-1a", "us-east-1b", "us-east-1c"]
  azs_secondary = ["us-west-2a", "us-west-2b", "us-west-2c"]
  
  # Primary region subnets
  public_subnet_cidrs_primary = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs_primary = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  
  # Secondary region subnets
  public_subnet_cidrs_secondary = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs_secondary = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
  
  # Subdomains
  ddc_subdomain = "ddc"
  monitoring_subdomain = "monitoring"
  
  # DDC Domain
  ddc_fully_qualified_domain_name = "${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  
  # Monitoring Domain
  monitoring_fully_qualified_domain_name = "${local.monitoring_subdomain}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
}