# AWS Provider - optional, can rely on environment/credentials
# provider "aws" {
#   region = "us-east-1"  # Default region
# }

# Primary Region AWS Provider
provider "aws" {
  alias  = "primary"
  region = local.primary_region
}

# Secondary Region AWS Provider
provider "aws" {
  alias  = "secondary"
  region = local.secondary_region
}

# Primary Region Kubernetes Provider
provider "kubernetes" {
  alias                  = "primary"
  host                   = module.ddc_infra_primary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.ddc_infra_primary.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.ddc_infra_primary.cluster_name, "--region", local.primary_region]
  }
}

# Secondary Region Kubernetes Provider
provider "kubernetes" {
  alias                  = "secondary"
  host                   = module.ddc_infra_secondary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.ddc_infra_secondary.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.ddc_infra_secondary.cluster_name, "--region", local.secondary_region]
  }
}

# Primary Region Helm Provider
provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = module.ddc_infra_primary.cluster_endpoint
    cluster_ca_certificate = base64decode(module.ddc_infra_primary.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.ddc_infra_primary.cluster_name, "--region", local.primary_region]
    }
  }
}

# Secondary Region Helm Provider
provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = module.ddc_infra_secondary.cluster_endpoint
    cluster_ca_certificate = base64decode(module.ddc_infra_secondary.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.ddc_infra_secondary.cluster_name, "--region", local.secondary_region]
    }
  }
}