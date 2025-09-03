# AWS Provider - No configuration needed!
# AWS Provider v6 supports region parameter on resources
# No aliases or explicit providers required

# Primary Region Kubernetes Provider
provider "kubernetes" {
  alias                  = "primary"
  host                   = module.unreal_cloud_ddc_primary.ddc_infra != null ? module.unreal_cloud_ddc_primary.ddc_infra.cluster_endpoint : null
  cluster_ca_certificate = module.unreal_cloud_ddc_primary.ddc_infra != null ? base64decode(module.unreal_cloud_ddc_primary.ddc_infra.cluster_certificate_authority_data) : null
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_primary.ddc_infra != null ? module.unreal_cloud_ddc_primary.ddc_infra.cluster_name : "", "--region", local.primary_region]
  }
}

# Secondary Region Kubernetes Provider
provider "kubernetes" {
  alias                  = "secondary"
  host                   = module.unreal_cloud_ddc_secondary.ddc_infra != null ? module.unreal_cloud_ddc_secondary.ddc_infra.cluster_endpoint : null
  cluster_ca_certificate = module.unreal_cloud_ddc_secondary.ddc_infra != null ? base64decode(module.unreal_cloud_ddc_secondary.ddc_infra.cluster_certificate_authority_data) : null
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_secondary.ddc_infra != null ? module.unreal_cloud_ddc_secondary.ddc_infra.cluster_name : "", "--region", local.secondary_region]
  }
}

# Primary Region Helm Provider
provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = module.unreal_cloud_ddc_primary.ddc_infra != null ? module.unreal_cloud_ddc_primary.ddc_infra.cluster_endpoint : null
    cluster_ca_certificate = module.unreal_cloud_ddc_primary.ddc_infra != null ? base64decode(module.unreal_cloud_ddc_primary.ddc_infra.cluster_certificate_authority_data) : null
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_primary.ddc_infra != null ? module.unreal_cloud_ddc_primary.ddc_infra.cluster_name : "", "--region", local.primary_region]
    }
  }
}

# Secondary Region Helm Provider
provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = module.unreal_cloud_ddc_secondary.ddc_infra != null ? module.unreal_cloud_ddc_secondary.ddc_infra.cluster_endpoint : null
    cluster_ca_certificate = module.unreal_cloud_ddc_secondary.ddc_infra != null ? base64decode(module.unreal_cloud_ddc_secondary.ddc_infra.cluster_certificate_authority_data) : null
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_secondary.ddc_infra != null ? module.unreal_cloud_ddc_secondary.ddc_infra.cluster_name : "", "--region", local.secondary_region]
    }
  }
}