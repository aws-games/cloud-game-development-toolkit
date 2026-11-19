##################################################
# Providers
##################################################

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

# The perforce module uses awscc-native resources (e.g. Secrets Manager) and
# declares awscc as a required provider. The awscc provider does not read
# var.region and has no other region source in this environment, so it must be
# explicitly configured here (mirroring the aws provider) to resolve its region.
provider "awscc" {
  region = var.region
}

# NOTE: The required netapp-ontap placeholder provider block lives in netapp.tf
# alongside the FSxN resources it relates to.
