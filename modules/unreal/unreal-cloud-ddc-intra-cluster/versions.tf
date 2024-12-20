terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.16.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.73.0"
    }
  }
}
