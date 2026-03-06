locals {
  # Match single-region naming pattern exactly
  project_prefix = "cgd"
  environment = "dev"
  name = "unreal-cloud-ddc"
  name_prefix = "${local.project_prefix}-${local.name}-${local.environment}"  # Same as single-region
  
  # Define regions
  primary_region = "us-east-1"
  secondary_region = "us-west-1"
}

# Dynamic AZ lookup for each region
data "aws_availability_zones" "primary" {
  region = local.primary_region
}

data "aws_availability_zones" "secondary" {
  region = local.secondary_region
}

locals {
  # Multi-region configuration - extensible for additional regions
  regions = {
    (local.primary_region) = {
      type = "primary"
      vpc_cidr = "10.0.0.0/16"
      azs = slice(data.aws_availability_zones.primary.names, 0, 2)
      public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
      private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24"]
    }
    (local.secondary_region) = {
      type = "secondary"
      vpc_cidr = "10.1.0.0/16"
      azs = slice(data.aws_availability_zones.secondary.names, 0, 2)
      public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
      private_subnet_cidrs = ["10.1.4.0/24", "10.1.5.0/24"]
    }
    # Future regions can be added here with type = "additional"
  }
  

  # Kubernetes version - ensure consistency across regions
  kubernetes_version = "1.33"
  
  # Common configuration
  unreal_cloud_ddc_version = "1.2.0"
  scylla_instance_type = "i4i.xlarge"
  
  # Network access
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  

  
  # DDC Domain
  ddc_subdomain = "ddc"
  primary_ddc_fully_qualified_domain_name = "${local.primary_region}.${local.environment}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  secondary_ddc_fully_qualified_domain_name = "${local.secondary_region}.${local.environment}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  
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
    
    # Multi-region context
    DeploymentType = "multi-region"
  }
}