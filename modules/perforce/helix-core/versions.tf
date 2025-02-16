terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.87.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.28.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
    netapp-ontap = {
        source  = "NetApp/netapp-ontap"
        version = "2.0.0"
    }
  }
}
