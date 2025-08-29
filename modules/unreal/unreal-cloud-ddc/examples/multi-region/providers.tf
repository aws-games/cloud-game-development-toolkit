provider "aws" {
  alias  = "primary"
  region = local.regions.primary.name
}

provider "aws" {
  alias  = "secondary"
  region = local.regions.secondary.name
}

provider "awscc" {
  alias  = "primary"
  region = local.regions.primary.name
}

provider "awscc" {
  alias  = "secondary"
  region = local.regions.secondary.name
}

provider "kubernetes" {
  alias                  = "primary"
  host                   = module.unreal_cloud_ddc.primary_region.eks_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc.primary_region.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.primary_region.eks_cluster_name, "--region", local.regions.primary.name]
  }
}

provider "kubernetes" {
  alias                  = "secondary"
  host                   = module.unreal_cloud_ddc.secondary_region.eks_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc.secondary_region.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.secondary_region.eks_cluster_name, "--region", local.regions.secondary.name]
  }
}

provider "helm" {
  alias = "primary"
  kubernetes = {
    host                   = module.unreal_cloud_ddc.primary_region.eks_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc.primary_region.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.primary_region.eks_cluster_name, "--region", local.regions.primary.name]
    }
  }
}

provider "helm" {
  alias = "secondary"
  kubernetes = {
    host                   = module.unreal_cloud_ddc.secondary_region.eks_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc.secondary_region.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.secondary_region.eks_cluster_name, "--region", local.regions.secondary.name]
    }
  }
}
