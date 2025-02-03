terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.82.2"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">=1.24.0"
    }
  }
}
