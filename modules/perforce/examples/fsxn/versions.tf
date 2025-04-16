terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.89.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.34.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = "2.1.1"
    }
  }
}
