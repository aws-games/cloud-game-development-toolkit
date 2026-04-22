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
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = "~> 2.3"
    }
  }
}
