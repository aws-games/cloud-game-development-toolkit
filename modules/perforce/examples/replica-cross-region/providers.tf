terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.70.0"
    }
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = ">= 0.1.0"
    }
  }
}

# Primary region (us-east-1)
provider "aws" {
  region = "us-east-1"
}

provider "awscc" {
  region = "us-east-1"
}

# Replica regions
provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "awscc" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

provider "awscc" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

# placeholder since provider is "required" by the module
provider "netapp-ontap" {
  connection_profiles = [
    {
      name     = "null"
      hostname = "null"
      username = "null"
      password = "null"
    }
  ]
}