locals {
  name_prefix = "teamcity"
  tags = {

  }
  image = "jetbrains/teamcity-server"
}

data "aws_region" "current" {}