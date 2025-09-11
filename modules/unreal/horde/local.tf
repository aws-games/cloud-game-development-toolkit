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

  server_config = {
    AuthMethod         = var.auth_method
    OidcAuthority      = var.oidc_authority
    OidcAudience       = var.oidc_audience
    OidcClientId       = var.oidc_client_id
    OidcClientSecret   = var.oidc_client_secret
    OidcSigninRedirect = var.oidc_signin_redirect
    AdminClaimType     = var.admin_claim_type
    AdminClaimValue    = var.admin_claim_value
  }

  dex_config = var.deploy_dex ? {
    issuer = "https://${var.dex_fqdn}"
    storage = {
      type = "memory"
    }
    web = {
      http = "0.0.0.0:${var.dex_container_port}"
    }
    connectors = var.dex_connectors
    staticClients = [{
      id     = "horde"
      name   = "Horde"
      public = true
      redirectURIs = [
        "https://${var.fully_qualified_domain_name}/signin-oidc",
        "http://localhost:5000/signin-oidc",
        "http://localhost:13340",
        "http://localhost:8749/ugs.client",
        "http://localhost:8749/",
      ]
    }]
  } : null
}
