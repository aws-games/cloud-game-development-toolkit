terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.6"
    }
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = "~> 2.3"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }
}
