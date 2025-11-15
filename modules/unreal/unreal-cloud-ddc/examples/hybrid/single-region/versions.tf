terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }

    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.0.0"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.0.0"
    }

  }
}