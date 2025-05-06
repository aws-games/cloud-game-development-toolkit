terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.89.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }

    # TESTING THIS TEAMCITY PROVIDER
    teamcity = {
      source = "jetbrains/teamcity"
    }
  }
}

provider "teamcity" {
  # host  = "http://localhost:8111"
  host = "https://teamcity.ayatanb.people.aws.dev"
  password = "6909622053639106778"
}

resource "teamcity_global_settings" "server_config" {
  root_url = "teamcity.ayatanb.people.aws.dev"
}
