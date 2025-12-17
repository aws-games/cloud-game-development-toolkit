terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.6"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.51"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
