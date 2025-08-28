terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0"
configuration_aliases = [
        aws.primary
      ]
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.26.0"
      configuration_aliases = [
        awscc.primary,
        awscc.secondary
      ]
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24.0"
      configuration_aliases = [
        kubernetes.primary,
        kubernetes.secondary
      ]
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
      configuration_aliases = [
        helm.primary,
        helm.secondary
      ]
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}