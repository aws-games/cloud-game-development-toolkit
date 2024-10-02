terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.38"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
  }
  required_version = ">= 1.0"
}


provider "kubernetes" {
  host                   = module.unreal_cloud_ddc_infra.cluster_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra.cluster_name, "--output", "json", "--profile", var.profile]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.unreal_cloud_ddc_infra.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra.cluster_name, "--output", "json", "--profile", var.profile]
    }
  }
  registry {
    url      = "oci://ghcr.io/epicgames"
    username = var.ghcr_username
    password = var.ghcr_password
  }
}
