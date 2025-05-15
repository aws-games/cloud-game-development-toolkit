terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.97.0"
    }
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = "2.1.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
  }
}
