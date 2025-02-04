terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.85.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.27.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
}
