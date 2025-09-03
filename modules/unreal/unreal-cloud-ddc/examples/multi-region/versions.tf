terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.50.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">=2.16.0, <3.0.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.12.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}
