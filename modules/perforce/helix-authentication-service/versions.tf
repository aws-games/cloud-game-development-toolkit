terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.16.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
}
