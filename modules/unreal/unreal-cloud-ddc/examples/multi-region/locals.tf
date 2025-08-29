data "aws_availability_zones" "available_region_1" {
  provider = aws.primary
  state    = "available"
}

data "aws_availability_zones" "available_region_2" {
  provider = aws.secondary
  state    = "available"
}

locals {
  project_prefix = "cgd"
  
  # Application Configuration
  ddc_namespace = "unreal-cloud-ddc"
  environment   = "dev"
  
  # Subdomains
  ddc_subdomain        = "ddc"
  monitoring_subdomain = "monitoring"
  
  # Region Configuration
  regions = {
    primary = {
      name  = "us-east-1"
      alias = "primary"
    }
    secondary = {
      name  = "us-east-2"
      alias = "secondary"
    }
  }
  
  # Availability zones
  azs_region_1 = slice(data.aws_availability_zones.available_region_1.names, 0, 2)
  azs_region_2 = slice(data.aws_availability_zones.available_region_2.names, 0, 2)
  
  # VPC Configuration
  vpc_cidr_primary     = "10.0.0.0/16"
  vpc_cidr_secondary   = "10.1.0.0/16"
  
  # Primary region subnets
  primary_public_subnet_cidrs  = ["10.0.2.0/24", "10.0.3.0/24"]
  primary_private_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
  
  # Secondary region subnets
  secondary_public_subnet_cidrs  = ["10.1.2.0/24", "10.1.3.0/24"]
  secondary_private_subnet_cidrs = ["10.1.0.0/24", "10.1.1.0/24"]

  tags = {
    Environment = local.environment
    Application = "unreal-cloud-ddc"
  }
}