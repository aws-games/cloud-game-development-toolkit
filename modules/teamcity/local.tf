locals {
  name_prefix = "teamcity"
  tags = merge(var.tags, {
    "environment" = var.environment
  })
  image                      = "jetbrains/teamcity-server"
  database_connection_string = "jdbc:postgresql://teamcity-cluster.cluster-cwmktevrnnqg.us-east-1.rds.amazonaws.com:5432/teamcity"
  database_user              = "teamcity"
  database_password          = "teamcity2025"
}
data "aws_region" "current" {}
