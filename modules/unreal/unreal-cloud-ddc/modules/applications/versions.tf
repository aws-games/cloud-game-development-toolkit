terraform {
  required_version = ">= 1.10.3"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.33.0"
    }
    helm = {
      source = "hashicorp/helm"
      # Upgrading to helm 3.0.0 will require some changes
      # https://registry.terraform.io/providers/hashicorp/helm/latest/docs/guides/v3-upgrade-guide
      version = ">=2.16.0, <3.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.73.0"
    }
  }
}
