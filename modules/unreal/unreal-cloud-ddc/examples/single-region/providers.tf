terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.89.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0, < 3.0.0"
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

# Basic providers - kubernetes and helm will be configured by the module
provider "aws" {}
provider "awscc" {}
provider "kubernetes" {}
provider "helm" {}