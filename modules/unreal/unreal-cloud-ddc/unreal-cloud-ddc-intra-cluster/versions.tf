terraform {
  required_version = ">= 1.10.3"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">=3.2.0"
    }
  }
}
