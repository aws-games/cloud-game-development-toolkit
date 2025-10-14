locals {
  name_prefix = "teamcity"
  tags = merge(var.tags, {
    "environment" = var.environment
  })

  # Database information
  database_connection_string = var.database_connection_string != null ? var.database_connection_string : "jdbc:postgresql://${aws_rds_cluster.teamcity_db_cluster[0].endpoint}/teamcity"
  database_master_username   = var.database_master_username != null ? var.database_master_username : aws_rds_cluster.teamcity_db_cluster[0].master_username
  database_master_password   = var.database_master_password != null ? var.database_master_password : null

  # Docker image to use for TeamCity Server
  image = "jetbrains/teamcity-server"

  # EFS information
  efs_file_system_id  = var.efs_id != null ? var.efs_id : aws_efs_file_system.teamcity_efs_file_system[0].id
  efs_file_system_arn = var.efs_id != null ? data.aws_efs_file_system.efs_file_system[0].arn : aws_efs_file_system.teamcity_efs_file_system[0].arn
  efs_access_point_id = var.efs_access_point_id != null ? var.efs_access_point_id : aws_efs_access_point.teamcity_efs_data_access_point[0].id

  # TeamCity Server Information
  # Set environment variables
  base_env = [
    {
      name  = "TEAMCITY_DB_URL"
      value = local.database_connection_string
    },
    {
      name  = "TEAMCITY_DB_USER"
      value = local.database_master_username
    },
    {
      name  = "TEAMCITY_DATA_PATH"
      value = "/data/teamcity_server/datadir"
    }
  ]
  # Define password environment variable if provided
  password_env = local.database_master_password != null ? [
    {
      name  = "TEAMCITY_DB_PASSWORD"
      value = local.database_master_password
    }
  ] : []

  # Service Connect namespace
  service_connect_namespace_arn = aws_service_discovery_http_namespace.teamcity.arn
}
data "aws_region" "current" {}

# Data source to look up existing EFS file system if ID is provided
data "aws_efs_file_system" "efs_file_system" {
  count          = var.efs_id != null ? 1 : 0
  file_system_id = var.efs_id
}
