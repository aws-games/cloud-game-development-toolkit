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

  elasticache_redis_port                 = 6379
  elasticache_redis_engine_version       = "7.0"
  elasticache_redis_parameter_group_name = "default.redis7"

  elasticache_connection_strings = [for node in aws_elasticache_cluster.horde[0].cache_nodes : "${node.address}:${node.port}"]

  redis_connection_config    = var.redis_connection_config != null ? var.redis_connection_config : join(",", local.elasticache_connection_strings)
  database_connection_string = var.database_connection_string != null ? var.database_connection_string : "mongodb://${var.docdb_master_username}:${var.docdb_master_password}@${aws_docdb_cluster.horde[0].endpoint}:27017/?tls=true&tlsCAFile=/app/config/global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"

  horde_service_env = [for config in [
    {
      name  = "Horde__authMethod"
      value = var.auth_method
    },
    {
      name  = "Horde__oidcAuthority"
      value = var.oidc_authority
    },
    {
      name  = "Horde__oidcAudience",
      value = var.oidc_audience
    },
    {
      name  = "Horde__oidcClientId"
      value = var.oidc_client_id
    },
    {
      name  = "Horde__oidcClientSecret"
      value = var.oidc_client_secret
    },
    {
      name  = "Horde__oidcSigninRedirect"
      value = var.oidc_signin_redirect
    },
    {
      name  = "Horde__adminClaimType"
      value = var.admin_claim_type
    },
    {
      name  = "Horde__adminClaimValue"
      value = var.admin_claim_value
    },
    {
      name  = "ASPNETCORE_ENVIRONMENT"
      value = var.environment
    }
  ] : config.value != null ? config : null]
}
