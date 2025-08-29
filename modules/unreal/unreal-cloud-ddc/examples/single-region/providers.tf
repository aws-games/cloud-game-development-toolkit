# Basic providers
provider "aws" {}
provider "awscc" {}
provider "kubernetes" {}
provider "helm" {}

# Null secondary providers for single-region (required by module but not used)
provider "aws" {
  alias  = "secondary"
  region = "null" # Placeholder - not used in single-region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

provider "awscc" {
  alias  = "secondary"
  region = "us-west-2" # Placeholder - not used in single-region
}

provider "kubernetes" {
  alias = "secondary"
  host  = "null" # Placeholder - not used in single-region
}

provider "helm" {
  alias = "secondary"
  kubernetes = {
    host = "null" # Placeholder - not used in single-region
  }
}
