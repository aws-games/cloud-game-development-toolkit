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

  # Rendered with placeholder tokens instead of credentials: the init container
  # substitutes the real values at startup from environment variables that ECS
  # injects from the p4_credentials_secret_arn secret. This keeps the credentials
  # out of the task definition JSON (visible in the ECS console and CloudTrail)
  # and out of the Terraform state's rendered container command.
  server_json = jsonencode({
    "Horde" = {
      "configPath"                 = var.config_path
      "forceConfigUpdateOnStartup" = true
      "enableNewAgentsByDefault"   = true
      "plugins" = var.p4_port != null ? {
        "build" = {
          "perforce" = [{
            "id"            = "default"
            "serverAndPort" = var.p4_port
            "credentials" = {
              "userName" = "__P4_USERNAME__"
              "password" = "__P4_PASSWORD__"
            }
          }]
        }
      } : {}
    }
  })

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
      name  = "ASPNETCORE_ENVIRONMENT"
      value = var.environment
    },
  ] : config.value != null ? config : null]

  # The Perforce connection and config path are now delivered to the server via the
  # rendered /app/Data/server.json file (see server_json above + the unreal-horde-init
  # container in ecs.tf), so the legacy Horde__Perforce__0__* env/secret entries on the
  # app container have been removed. The credentials themselves are injected into the
  # init container (not the app container) from p4_credentials_secret_arn.
  horde_service_secrets = []

  # ECS-native Secrets Manager injection for the init container: the execution role
  # fetches the JSON secret and exposes its username/password keys as environment
  # variables, which the init script substitutes into server.json at startup.
  horde_init_secrets = var.p4_credentials_secret_arn != null ? [
    {
      name      = "P4_USERNAME"
      valueFrom = "${var.p4_credentials_secret_arn}:username::"
    },
    {
      name      = "P4_PASSWORD"
      valueFrom = "${var.p4_credentials_secret_arn}:password::"
    },
  ] : []
}
