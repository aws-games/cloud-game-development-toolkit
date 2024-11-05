terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.73.0"
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
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra.cluster_name, "--output", "json"]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.unreal_cloud_ddc_infra.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra.cluster_name, "--output", "json"]
    }
  }
  registry {
    url      = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}
