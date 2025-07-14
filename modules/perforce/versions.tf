terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.97.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.34.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
  }
}
