terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.0.0-beta1"
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
      version = ">= 2.9.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.5"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.26.0"
    }
  }
  required_version = ">= 1.10.3"
}

provider "kubernetes" {
  alias                  = "us-west-2"
  host                   = module.unreal_cloud_ddc_infra_us_west_2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra_us_west_2.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra_us_west_2.cluster_name, "--output", "json"]
  }
}

provider "helm" {
  alias = "us-west-2"
  kubernetes {
    host                   = module.unreal_cloud_ddc_infra_us_west_2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra_us_west_2.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra_us_west_2.cluster_name, "--output", "json"]
    }
  }
  registry {
    url      = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.us_west_2.region}.amazonaws.com"
    username = data.aws_ecr_authorization_token.token_us_west_2.user_name
    password = data.aws_ecr_authorization_token.token_us_west_2.password
  }
}

provider "kubernetes" {
  alias                  = "us-east-2"
  host                   = module.unreal_cloud_ddc_infra_us_east_2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra_us_east_2.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra_us_east_2.cluster_name, "--output", "json"]
  }
}

provider "helm" {
  alias = "us-east-2"
  kubernetes {
    host                   = module.unreal_cloud_ddc_infra_us_east_2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.unreal_cloud_ddc_infra_us_east_2.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.unreal_cloud_ddc_infra_us_east_2.cluster_name, "--output", "json"]
    }
  }
  registry {
    url      = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.us_east_2.region}.amazonaws.com"
    username = data.aws_ecr_authorization_token.token_us_east_2.user_name
    password = data.aws_ecr_authorization_token.token_us_east_2.password
  }
}
