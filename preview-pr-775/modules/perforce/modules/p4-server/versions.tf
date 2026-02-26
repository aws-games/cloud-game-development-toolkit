terraform {
  required_version = ">= 1.0"

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
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = "~> 2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
