terraform {
  required_version = ">= 1.10.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.0.0-beta1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.6"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}
