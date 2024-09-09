# - Random Strings to prevent naming conflicts -
resource "random_string" "unreal_horde" {
  length  = 4
  special = false
  upper   = false
}

data "aws_region" "current" {}

locals {
  image       = "ghcr.io/epicgames/horde-server:latest-bundled"
  name_prefix = "${var.project_prefix}-${var.name}"
  tags = merge(var.tags, {
    "ENVIRONMENT" = var.environment
  })

  redis_connection_config    = var.redis_connection_config != null ? var.redis_connection_config : "${aws_elasticache_serverless_cache.horde.endpoint[0].address}:${aws_elasticache_serverless_cache.horde.endpoint[0].port},ssl=true"
  database_connection_string = var.database_connection_string != null ? var.database_connection_string : "mongodb://${var.docdb_master_username}:${var.docdb_master_password}@${aws_docdb_cluster.horde.endpoint}:27017/?retryWrites=false"
}
