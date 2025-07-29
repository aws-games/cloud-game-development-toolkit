terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.50.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = "2.3.0"
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
