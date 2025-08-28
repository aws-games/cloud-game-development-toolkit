# Improved availability zone handling with opt-in status filter
data "aws_availability_zones" "available_region_1" {
  provider = aws.primary
  
  # Filter for standard AZs only
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
  
  state = "available"
}

data "aws_availability_zones" "available_region_2" {
  provider = aws.secondary
  
  # Filter for standard AZs only
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
  
  state = "available"
}

# EKS cluster data sources for provider configuration
data "aws_eks_cluster" "primary" {
  provider = aws.primary
  name     = module.unreal_cloud_ddc.primary_region.eks_cluster_name
}

data "aws_eks_cluster" "secondary" {
  provider = aws.secondary
  name     = module.unreal_cloud_ddc.secondary_region.eks_cluster_name
}

locals {
  # Dynamic AZ selection
  azs_region_1 = slice(data.aws_availability_zones.available_region_1.names, 0, 2)
  azs_region_2 = slice(data.aws_availability_zones.available_region_2.names, 0, 2)
  
  # Common tags
  common_tags = merge(var.additional_tags, {
    Environment = var.environment
    Project     = var.project_prefix
  })
}