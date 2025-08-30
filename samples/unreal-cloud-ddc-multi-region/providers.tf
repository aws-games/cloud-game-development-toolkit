terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=6.2.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">=3.5.1"
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

provider "awscc" {
  alias  = "region-1"
  region = var.regions[0]
}

provider "awscc" {
  alias  = "region-2"
  region = var.regions[1]
}

provider "kubernetes" {
  alias = "region-1"
  # Use empty config - will be configured by modules when needed
}

provider "helm" {
  alias = "region-1"
  # Use empty config - will be configured by modules when needed
}

provider "kubernetes" {
  alias = "region-2"
  # Use empty config - will be configured by modules when needed
}

provider "helm" {
  alias = "region-2"
  # Use empty config - will be configured by modules when needed
}

provider "aws" {
  alias  = "region-1"
  region = var.regions[0]
}

provider "aws" {
  alias  = "region-2"
  region = var.regions[1]
}
