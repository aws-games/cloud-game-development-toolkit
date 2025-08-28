# Dynamic provider configuration based on variables
provider "aws" {
  region = var.regions[0]
}

provider "awscc" {
  alias  = "primary"
  region = var.regions[0]
}

provider "awscc" {
  alias  = "secondary"
  region = var.regions[1]
}

provider "aws" {
  alias  = "primary"
  region = var.regions[0]
}

provider "aws" {
  alias  = "secondary"
  region = var.regions[1]
}

# Kubernetes providers (configured after EKS clusters are created)
provider "kubernetes" {
  alias                  = "primary"
  host                   = module.unreal_cloud_ddc.primary_region.eks_endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.primary_region.eks_cluster_name, "--region", var.regions[0]]
  }
}

provider "kubernetes" {
  alias                  = "secondary"
  host                   = module.unreal_cloud_ddc.secondary_region.eks_endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.secondary_region.eks_cluster_name, "--region", var.regions[1]]
  }
}

provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = module.unreal_cloud_ddc.primary_region.eks_endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.primary_region.eks_cluster_name, "--region", var.regions[0]]
    }
  }
}

provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = module.unreal_cloud_ddc.secondary_region.eks_endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.secondary_region.eks_cluster_name, "--region", var.regions[1]]
    }
  }
}