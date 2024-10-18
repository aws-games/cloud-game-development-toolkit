terraform {
  required_version = ">= 1.5"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.9.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.38"
    }
  }
}
