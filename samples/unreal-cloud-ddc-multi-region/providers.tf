terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.2.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.5"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.26.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.2.0"
    }
  }
  required_version = ">= 1.10.3"
}

provider "aws" {
  alias  = "region-1"
  region = "us-west-2"
}

provider "aws" {
  alias  = "region-2"
  region = "us-east-2"
}

provider "kubernetes" {
  alias                  = "region-1"
  host                   = module.unreal_cloud_ddc_infra_region_1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra_region_1.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra_region_1.cluster_name, "--output", "json"]
  }
}

provider "helm" {
  alias = "region-1"
  kubernetes {
    host                   = module.unreal_cloud_ddc_infra_region_1.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra_region_1.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra_region_1.cluster_name, "--output", "json"]
    }
  }
  registry {
    url      = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.region_1.region}.amazonaws.com"
    username = data.aws_ecr_authorization_token.token_region_1.user_name
    password = data.aws_ecr_authorization_token.token_region_1.password
  }
}

provider "kubernetes" {
  alias                  = "region-2"
  host                   = module.unreal_cloud_ddc_infra_region_2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra_region_2.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra_region_2.cluster_name, "--output", "json"]
  }
}

provider "helm" {
  alias = "region-2"
  kubernetes {
    host                   = module.unreal_cloud_ddc_infra_region_2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra_region_2.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra_region_2.cluster_name, "--output", "json"]
    }
  }
  registry {
    url      = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.region_2.region}.amazonaws.com"
    username = data.aws_ecr_authorization_token.token_region_2.user_name
    password = data.aws_ecr_authorization_token.token_region_2.password
  }
}
