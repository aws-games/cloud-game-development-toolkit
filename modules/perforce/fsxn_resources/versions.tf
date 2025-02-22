terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.83.1"
    }
    netapp-ontap = {
        source  = "NetApp/netapp-ontap"
        version = "2.0.0"
    }
  }
}
