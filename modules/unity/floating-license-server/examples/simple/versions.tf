terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 2.0"
    }
  }
}
