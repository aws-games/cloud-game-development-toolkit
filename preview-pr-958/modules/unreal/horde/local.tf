# - Random Strings to prevent naming conflicts -
resource "random_string" "unreal_horde" {
  length  = 4
  special = false
  upper   = false
}

data "aws_region" "current" {}

locals {
  name_prefix = "${var.project_prefix}-${var.name}"
  tags = merge(var.tags, {
    "environment" = var.environment
  })

  elasticache_redis_connection_strings = var.elasticache_engine == "redis" ? [for node in aws_elasticache_cluster.horde[0].cache_nodes : "${node.address}:${node.port}"] : null

  elasticache_valkey_connection_strings = var.elasticache_engine == "valkey" ? "${aws_elasticache_replication_group.horde[0].primary_endpoint_address}:${var.elasticache_port}" : null

  redis_connection_config = var.custom_cache_connection_config != null ? var.custom_cache_connection_config : (var.elasticache_engine == "redis" ? join(",", local.elasticache_redis_connection_strings) : local.elasticache_valkey_connection_strings)

  database_connection_string = var.database_connection_string != null ? var.database_connection_string : "mongodb://${var.docdb_master_username}:${var.docdb_master_password}@${aws_docdb_cluster.horde[0].endpoint}:27017/?tls=true&tlsCAFile=/app/config/global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"

  need_p4_trust = var.p4_port != null && startswith(var.p4_port, "ssl:")

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
      name  = "Horde__enableNewAgentsByDefault",
      value = tostring(var.enable_new_agents_by_default)
    },
    {
      name  = "Horde__Perforce__0__ServerAndPort"
      value = var.p4_port
    },
    {
      name  = "ASPNETCORE_ENVIRONMENT"
      value = var.environment
    }
  ] : config.value != null ? config : null]

  horde_service_secrets = [for config in [
    {
      name      = "Horde__Perforce__0__credentials__username"
      valueFrom = var.p4_super_user_username_secret_arn
    },
    {
      name      = "Horde__Perforce__0__credentials__password"
      valueFrom = var.p4_super_user_password_secret_arn
    },
  ] : config.valueFrom != null ? config : null]
}
