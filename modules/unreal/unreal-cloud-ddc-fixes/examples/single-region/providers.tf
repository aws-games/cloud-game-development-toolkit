# AWS Provider - optional, can rely on environment/credentials
# provider "aws" {
#   region = local.region
# }

# Kubernetes provider configuration for EKS cluster
provider "kubernetes" {
  host                   = module.unreal_cloud_ddc.ddc_infra != null ? module.unreal_cloud_ddc.ddc_infra.cluster_endpoint : null
  cluster_ca_certificate = module.unreal_cloud_ddc.ddc_infra != null ? base64decode(module.unreal_cloud_ddc.ddc_infra.cluster_certificate_authority_data) : null

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.ddc_infra != null ? module.unreal_cloud_ddc.ddc_infra.cluster_name : ""]
  }
}

# Helm provider configuration for EKS cluster (v3+ syntax)
provider "helm" {
  kubernetes {
    host                   = module.unreal_cloud_ddc.ddc_infra != null ? module.unreal_cloud_ddc.ddc_infra.cluster_endpoint : null
    cluster_ca_certificate = module.unreal_cloud_ddc.ddc_infra != null ? base64decode(module.unreal_cloud_ddc.ddc_infra.cluster_certificate_authority_data) : null

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc.ddc_infra != null ? module.unreal_cloud_ddc.ddc_infra.cluster_name : ""]
    }
  }
}
