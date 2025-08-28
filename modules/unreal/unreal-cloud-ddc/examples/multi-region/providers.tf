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

# Data sources for EKS clusters (referenced in locals.tf)
data "aws_eks_cluster" "primary" {
  provider = aws.primary
  name     = "${var.project_prefix}-primary-cluster"
  
  depends_on = [module.unreal_cloud_ddc]
}

data "aws_eks_cluster" "secondary" {
  provider = aws.secondary
  name     = "${var.project_prefix}-secondary-cluster"
  
  depends_on = [module.unreal_cloud_ddc]
}

# Kubernetes providers
provider "kubernetes" {
  alias                  = "primary"
  host                   = try(data.aws_eks_cluster.primary.endpoint, "")
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data), "")
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "${var.project_prefix}-primary-cluster", "--region", var.regions[0]]
  }
}

provider "kubernetes" {
  alias                  = "secondary"
  host                   = try(data.aws_eks_cluster.secondary.endpoint, "")
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data), "")
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "${var.project_prefix}-secondary-cluster", "--region", var.regions[1]]
  }
}

provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = try(data.aws_eks_cluster.primary.endpoint, "")
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data), "")
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "${var.project_prefix}-primary-cluster", "--region", var.regions[0]]
    }
  }
}

provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = try(data.aws_eks_cluster.secondary.endpoint, "")
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data), "")
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "${var.project_prefix}-secondary-cluster", "--region", var.regions[1]]
    }
  }
}