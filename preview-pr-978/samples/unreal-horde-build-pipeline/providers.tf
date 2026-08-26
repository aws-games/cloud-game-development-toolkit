##################################################
# Providers
##################################################

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# NOTE: The required netapp-ontap placeholder provider block lives in netapp.tf
# alongside the FSxN resources it relates to.
