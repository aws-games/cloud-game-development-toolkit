locals {
  name_prefix = "teamcity"
  tags = merge(var.tags, {
    "environment" = var.environment
  })
  image = "jetbrains/teamcity-server"
}
data "aws_region" "current" {}
