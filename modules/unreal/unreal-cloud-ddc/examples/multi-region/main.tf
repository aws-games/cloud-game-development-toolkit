# Multi-region example using unified module with config objects
module "unreal_cloud_ddc" {
  source = "../../"
  
  providers = {
    aws.primary        = aws.primary
    aws.secondary      = aws.secondary
    awscc.primary      = awscc.primary
    awscc.secondary    = awscc.secondary
    kubernetes.primary = kubernetes.primary
    kubernetes.secondary = kubernetes.secondary
    helm.primary       = helm.primary
    helm.secondary     = helm.secondary
  }
  
  # Multi-region Configuration
  regions = {
    primary   = { region = var.regions[0] }
    secondary = { region = var.regions[1] }
  }
  
  # VPC Configuration
  vpc_ids = {
    primary   = aws_vpc.primary.id
    secondary = aws_vpc.secondary.id
  }
  
  # Infrastructure Configuration
  infrastructure_config = {
    name           = var.project_prefix
    project_prefix = var.project_prefix
    environment    = var.environment
    
    # EKS Configuration
    kubernetes_version      = var.eks_cluster_version
    eks_node_group_subnets = aws_subnet.primary_private[*].id
    
    # ScyllaDB Configuration
    scylla_subnets       = aws_subnet.primary_private[*].id
    scylla_instance_type = var.scylla_instance_type
    
    # Load Balancer Configuration
    monitoring_application_load_balancer_subnets = aws_subnet.primary_public[*].id
  }
  
  # Application Configuration
  application_config = {
    name           = var.project_prefix
    project_prefix = var.project_prefix
    
    # Credentials
    ghcr_credentials_secret_manager_arn = var.github_credential_arn_region_1
    
    # Application Settings
    unreal_cloud_ddc_namespace = "unreal-cloud-ddc"
  }
  
  tags = var.additional_tags
}

# Primary region VPC
resource "aws_vpc" "primary" {
  provider = aws.primary
  
  cidr_block           = var.vpc_cidr_region_1
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-vpc"
  })
}

# Secondary region VPC
resource "aws_vpc" "secondary" {
  provider = aws.secondary
  
  cidr_block           = var.vpc_cidr_region_2
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-vpc"
  })
}

# Primary region subnets
resource "aws_subnet" "primary_public" {
  provider = aws.primary
  count    = 2

  vpc_id                  = aws_vpc.primary.id
  cidr_block              = cidrsubnet(var.vpc_cidr_region_1, 8, count.index + 1)
  availability_zone       = local.azs_region_1[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-public-${count.index + 1}"
  })
}

resource "aws_subnet" "primary_private" {
  provider = aws.primary
  count    = 2

  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(var.vpc_cidr_region_1, 8, count.index + 3)
  availability_zone = local.azs_region_1[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-private-${count.index + 1}"
  })
}

# Secondary region subnets
resource "aws_subnet" "secondary_public" {
  provider = aws.secondary
  count    = 2

  vpc_id                  = aws_vpc.secondary.id
  cidr_block              = cidrsubnet(var.vpc_cidr_region_2, 8, count.index + 1)
  availability_zone       = local.azs_region_2[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-public-${count.index + 1}"
  })
}

resource "aws_subnet" "secondary_private" {
  provider = aws.secondary
  count    = 2

  vpc_id            = aws_vpc.secondary.id
  cidr_block        = cidrsubnet(var.vpc_cidr_region_2, 8, count.index + 3)
  availability_zone = local.azs_region_2[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-private-${count.index + 1}"
  })
}