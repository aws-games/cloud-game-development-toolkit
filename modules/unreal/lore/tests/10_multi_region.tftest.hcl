mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-2", region = "us-east-2" }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-2a", "us-east-2b"]
    }
  }
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-12345678" }
  }
  mock_resource "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:us-east-2:123456789012:table/mock" }
  }
  mock_data "aws_dynamodb_table" {
    defaults = { arn = "arn:aws:dynamodb:us-west-2:123456789012:table/mock" }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "archive" {}

variables {
  project_prefix        = "lore"
  environment           = "dev"
  container_image       = "123456789012.dkr.ecr.us-east-2.amazonaws.com/loreserver:v0.10.1"
  allowed_ingress_cidrs = ["10.0.0.0/8"]
}

# =============================================================================
# Defaults: a single-region deployment gains nothing new
# =============================================================================

run "single_region_has_no_cross_region_resources" {
  command = plan

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.replication_cidr_grpc) == 0 &&
      length(aws_vpc_security_group_egress_rule.replication_cidr_udp) == 0 &&
      length(aws_vpc_security_group_ingress_rule.replication_quic) == 0 &&
      length(aws_vpc_security_group_egress_rule.replication_egress) == 0
    )
    error_message = "A single-region root with no edge pods or peers must not expose port 41340"
  }
  assert {
    condition     = length([for e in module.compute.listener_env_vars : e if startswith(e.name, "LORE__SERVER__QUIC_INTERNAL")]) == 0
    error_message = "The internal QUIC listener must stay disabled by default"
  }
  assert {
    condition = (
      module.compute.replication_client_certificate_secret_arn == null &&
      module.compute.replication_client_private_key_secret_arn == null
    )
    error_message = "A tier with no outgoing replication client must not create unused client-identity secrets"
  }
  assert {
    condition     = module.compute.topology_toml == ""
    error_message = "No topology overlay without replication_peers"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__MUTABLE_STORE__MODE"]) == "aws" && one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__LOCK_STORE__MODE"]) == "aws"
    error_message = "Write tier keeps the DynamoDB mutable and lock stores"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__PLUGINS__AWS__IMMUTABLE_STORE__DYNAMODB_FRAGMENT_STATE_TABLE"]) == "lore-dev-fragment-metadata"
    error_message = "loreserver >= v0.9.0 requires the fragment state table"
  }
  assert {
    condition     = length([for e in module.compute.store_env_vars : e if e.name == "LORE__PLUGINS__AWS__MUTABLE_STORE__DYNAMODB_REGION"]) == 0
    error_message = "Write tier uses its own region's table; no region override"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE_CONFIG_PATH"]) == "/etc/lore/overlay"
    error_message = "Server must read the overlay directory where the topology file is written"
  }
  assert {
    condition     = length(aws_vpc_endpoint.dynamodb_interface) == 0 && output.dynamodb_interface_endpoint_url == null
    error_message = "Single-region defaults must not add a billed DynamoDB interface endpoint"
  }
}

# =============================================================================
# CIDR ingress/egress for tiers across inter-region peering
# =============================================================================

run "replication_cidrs_open_only_required_udp_replication_rules" {
  command = plan

  variables {
    replication_ingress_cidrs = ["10.20.0.0/16", "10.30.0.0/16"]
    trusted_ca_pem            = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.replication_cidr_grpc) == 2 &&
      length(aws_vpc_security_group_ingress_rule.replication_cidr_quic) == 2 &&
      length(aws_vpc_security_group_ingress_rule.replication_cidr_udp) == 2
    )
    error_message = "One ingress rule per CIDR for 41337/tcp, 41337/udp, and mTLS replication on 41340/udp"
  }
  assert {
    condition = (
      length(aws_vpc_security_group_egress_rule.replication_cidr_grpc) == 2 &&
      length(aws_vpc_security_group_egress_rule.replication_cidr_quic) == 2 &&
      length(aws_vpc_security_group_egress_rule.replication_cidr_udp) == 2
    )
    error_message = "Matching egress rules must allow only the required client and QUIC replication protocols"
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.replication_cidr_udp["10.20.0.0/16"].from_port == 41340 && aws_vpc_security_group_ingress_rule.replication_cidr_udp["10.20.0.0/16"].ip_protocol == "udp"
    error_message = "Replication must use 41340/udp only"
  }
}

run "replication_cidrs_reject_open_internet" {
  command = plan

  variables {
    replication_ingress_cidrs = ["0.0.0.0/0"]
    trusted_ca_pem            = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
  }

  expect_failures = [var.replication_ingress_cidrs]
}

# =============================================================================
# Topology peers → TOML overlay
# =============================================================================

run "replication_peers_render_fixed_topology_overlay" {
  command = plan

  variables {
    replication_peers = [
      { address = "regional-tier.lore-dev-replica.internal", locality = "OtherRegion" },
      { address = "10.10.1.50", port = 41341, locality = "SameRegion" },
    ]
    enable_same_region_write = false
    trusted_ca_pem           = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
  }

  assert {
    condition     = strcontains(module.compute.topology_toml, "provider = \"rotating_id_fixed\"") && strcontains(module.compute.topology_toml, "rotation_interval_seconds = 300")
    error_message = "Overlay must select the rotating fixed topology so peer DNS is re-resolved"
  }
  assert {
    condition     = strcontains(module.compute.topology_toml, "{ address = \"regional-tier.lore-dev-replica.internal\", port = 41340, locality = \"OtherRegion\" }")
    error_message = "Peer must render with Lore's exact PascalCase locality and the default port"
  }
  assert {
    condition     = strcontains(module.compute.topology_toml, "port = 41341, locality = \"SameRegion\"")
    error_message = "Explicit port must be honoured"
  }
  assert {
    condition     = strcontains(module.compute.topology_toml, "[immutable_store.composite.replica_factory]") && strcontains(module.compute.topology_toml, "enable_same_region_write = false")
    error_message = "Replica factory block is what makes Lore act on the peers; enable_same_region_write must pass through"
  }
  assert {
    condition = (
      strcontains(module.compute.topology_toml, "[immutable_store.composite.replica_factory.tls]") &&
      strcontains(module.compute.topology_toml, "server_sni = \"loreserver.internal\"") &&
      strcontains(module.compute.topology_toml, "[immutable_store.composite.replica_factory.tls.client_certs]") &&
      strcontains(module.compute.topology_toml, "cert_file = \"/certs/replication-client.crt\"") &&
      strcontains(module.compute.topology_toml, "cert_chain = \"/etc/lore/overlay/replication-ca-bundle.pem\"")
    )
    error_message = "Every topology peer must use a client certificate and validated server certificate"
  }
  assert {
    condition     = toset(module.compute.replication_client_allowed_uses) == toset(["digital_signature", "key_encipherment", "client_auth"])
    error_message = "The generated replication identity must be a clientAuth certificate, not a server identity"
  }
  assert {
    condition     = !module.compute.peer_ca_added_to_system_trust
    error_message = "Topology peer CAs must remain scoped to replication TLS when the mutable store is local"
  }
  assert {
    condition     = !strcontains(module.compute.topology_toml, "locality = \"same_region\"")
    error_message = "The old snake_case locality never deserialized in Lore; it must not come back"
  }
}

run "replication_peers_reject_unknown_locality" {
  command = plan

  variables {
    replication_peers = [{ address = "10.10.1.50", locality = "same_region" }]
  }

  expect_failures = [var.replication_peers]
}

# =============================================================================
# Outputs a regional cache consumes
# =============================================================================

run "root_exposes_what_a_regional_cache_needs" {
  command = plan

  assert {
    condition     = output.write_tier_dns_name == "write-tier.lore-dev.internal"
    error_message = "write_tier_dns_name"
  }
  assert {
    condition     = output.vpc_cidr == "10.0.0.0/16"
    error_message = "vpc_cidr for the peer's CIDR rules"
  }
  assert {
    condition     = output.locks_table_name == "lore-dev-locks"
    error_message = "locks_table_name"
  }
  assert {
    condition     = output.mutable_store_table_name == "lore-dev-mutable-typed-store"
    error_message = "mutable_store_table_name"
  }
}

# =============================================================================
# Regional cache submodule — NVMe over the write tier, no storage of its own
# =============================================================================

run "regional_cache_has_no_storage_and_points_at_the_write_region" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.10.1"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    instance_type                 = "c8gd.large"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_region_rtt_ms           = 55
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    dynamodb_endpoint_url         = "https://vpce-0123456789abcdef0-abc123.dynamodb.us-east-2.vpce.amazonaws.com"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
  }

  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__MODE"]) == "replicated"
    error_message = "The cache's durable tier must be the write tier (replicated)"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__REMOTE_URL"]) == "lores://write-tier.lore-dev.internal:41340"
    error_message = "Durable remote must validate the write tier's certificate over secure QUIC"
  }
  assert {
    condition = (
      one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__CERTS__CERT_FILE"]) == "/certs/replication-client.crt" &&
      one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__CERTS__PKEY_FILE"]) == "/certs/replication-client.key" &&
      one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__CERTS__CERT_CHAIN"]) == "/etc/lore/overlay/replication-ca-bundle.pem"
    )
    error_message = "The durable replicated client must present its dedicated mTLS identity"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__EXPECTED_RTT_MS"]) == "55"
    error_message = "write_region_rtt_ms must tune the replicated client"
  }
  assert {
    condition     = length([for e in module.compute.store_env_vars : e if startswith(e.name, "LORE__PLUGINS__AWS__IMMUTABLE_STORE")]) == 0
    error_message = "A cache has no S3 bucket or immutable tables to configure"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__PLUGINS__AWS__MUTABLE_STORE__DYNAMODB_REGION"]) == "us-east-2" && one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__PLUGINS__AWS__LOCK_STORE__DYNAMODB_REGION"]) == "us-east-2"
    error_message = "Branch pointers and locks must be the write region's tables"
  }
  assert {
    condition = (
      one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__PLUGINS__AWS__MUTABLE_STORE__DYNAMODB_ENDPOINT_URL"]) == "https://vpce-0123456789abcdef0-abc123.dynamodb.us-east-2.vpce.amazonaws.com" &&
      one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__PLUGINS__AWS__LOCK_STORE__DYNAMODB_ENDPOINT_URL"]) == "https://vpce-0123456789abcdef0-abc123.dynamodb.us-east-2.vpce.amazonaws.com"
    )
    error_message = "The cache must send branch-pointer and lock clients through the write VPC interface endpoint"
  }
  assert {
    condition     = output.cache_dns_name == "regional-cache.lore-dev-london.internal"
    error_message = "cache_dns_name"
  }
  assert {
    condition     = !module.compute.peer_ca_added_to_system_trust
    error_message = "Replication-only peer CAs must not broaden the process-wide system trust store"
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.write_region_replication_udp[0].from_port == 41340 && aws_vpc_security_group_ingress_rule.write_region_replication_udp[0].cidr_ipv4 == "10.10.0.0/16"
    error_message = "The write tier must be able to push into the cache on 41340/udp"
  }
}

run "regional_cache_can_forward_branch_pointers_to_the_write_tier_without_auth" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.10.1"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    instance_type                 = "c8gd.large"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_region_rtt_ms           = 55
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    branch_pointer_access         = "write_tier"
  }

  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__MUTABLE_STORE__MODE"]) == "remote"
    error_message = "write_tier must use Lore's remote mutable store"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__MUTABLE_STORE__REMOTE__REMOTE_URL"]) == "lores://write-tier.lore-dev.internal:41337"
    error_message = "The remote mutable store must point at the write tier's client port"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__LOCK_STORE__MODE"]) == "aws" && one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__PLUGINS__AWS__LOCK_STORE__DYNAMODB_REGION"]) == "us-east-2"
    error_message = "Locks stay on the write region's DynamoDB table"
  }
  assert {
    condition     = module.compute.peer_ca_added_to_system_trust
    error_message = "The secure remote mutable-store client must receive the write-tier CA through SSL_CERT_FILE"
  }
}

run "regional_cache_rejects_unknown_branch_pointer_access" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.10.1"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    instance_type                 = "c8gd.large"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_region_rtt_ms           = 55
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    branch_pointer_access         = "edge"
  }

  expect_failures = [var.branch_pointer_access]
}

# =============================================================================
# Regional cache auth — only supported modes, fail closed
# =============================================================================

run "regional_cache_external_auth_sets_jwt_env" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    auth_mode                     = "external"
    auth_jwk_endpoint             = "https://login.example.com/.well-known/jwks.json"
    auth_jwt_issuer               = "https://login.example.com"
    auth_jwt_audience             = ["lore-server"]
  }

  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__MUTABLE_STORE__MODE"]) == "aws"
    error_message = "With auth, branch pointers must use the write region's DynamoDB table"
  }
  assert {
    condition = (
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__AUTH__JWK__ENDPOINT"]) == "https://login.example.com/.well-known/jwks.json" &&
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__AUTH__JWT_ISSUER"]) == "https://login.example.com" &&
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__AUTH__JWT_AUDIENCE"]) == "lore-server"
    )
    error_message = "External auth must reach loreserver as JWK endpoint, issuer and audience"
  }
}

run "regional_cache_rejects_write_tier_branch_pointers_with_auth" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    branch_pointer_access         = "write_tier"
    auth_mode                     = "external"
    auth_jwk_endpoint             = "https://login.example.com/.well-known/jwks.json"
    auth_jwt_issuer               = "https://login.example.com"
    auth_jwt_audience             = ["lore-server"]
  }

  expect_failures = [var.branch_pointer_access]
}

run "regional_cache_rejects_cognito_auth_mode" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    auth_mode                     = "cognito"
  }

  expect_failures = [var.auth_mode]
}

run "regional_cache_external_auth_requires_https_jwk" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    auth_mode                     = "external"
    auth_jwk_endpoint             = "http://login.example.com/.well-known/jwks.json"
    auth_jwt_issuer               = "https://login.example.com"
    auth_jwt_audience             = ["lore-server"]
  }

  expect_failures = [var.auth_jwk_endpoint]
}

run "regional_cache_external_auth_requires_jwk_and_issuer" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    auth_mode                     = "external"
    auth_jwt_audience             = ["lore-server"]
  }

  expect_failures = [var.auth_jwk_endpoint, var.auth_jwt_issuer]
}

run "regional_cache_external_auth_requires_https_issuer" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    auth_mode                     = "external"
    auth_jwk_endpoint             = "https://login.example.com/.well-known/jwks.json"
    auth_jwt_issuer               = "login.example.com"
    auth_jwt_audience             = ["lore-server"]
  }

  expect_failures = [var.auth_jwt_issuer]
}

run "regional_cache_external_auth_requires_audience" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    auth_mode                     = "external"
    auth_jwk_endpoint             = "https://login.example.com/.well-known/jwks.json"
    auth_jwt_issuer               = "https://login.example.com"
    auth_jwt_audience             = []
  }

  expect_failures = [var.auth_jwt_audience]
}

run "regional_cache_external_auth_rejects_blank_audience" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    auth_mode                     = "external"
    auth_jwk_endpoint             = "https://login.example.com/.well-known/jwks.json"
    auth_jwt_issuer               = "https://login.example.com"
    auth_jwt_audience             = [" "]
  }

  expect_failures = [var.auth_jwt_audience]
}

# =============================================================================
# Port 41340 — fail-closed mTLS plus subnet-scoped network defense in depth
# =============================================================================

run "regional_cache_41340_requires_mtls_and_defaults_to_write_vpc" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.write_region_replication_udp) == 1 &&
      aws_vpc_security_group_ingress_rule.write_region_replication_udp[0].cidr_ipv4 == "10.10.0.0/16" &&
      length(aws_vpc_security_group_egress_rule.write_region_replication_udp) == 1 &&
      aws_vpc_security_group_egress_rule.write_region_replication_udp[0].cidr_ipv4 == "10.10.0.0/16"
    )
    error_message = "Without write_tier_replication_cidrs, 41340/udp falls back to the write VPC CIDR"
  }
  assert {
    condition = (
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__QUIC_INTERNAL__VERIFY_CLIENT_CERTS"]) == "true" &&
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__QUIC_INTERNAL__CERTIFICATE__CERT_CHAIN"]) == "/etc/lore/overlay/replication-ca-bundle.pem"
    )
    error_message = "The regional cache's internal QUIC listener must fail closed with mTLS"
  }
  assert {
    condition     = output.private_subnet_cidrs == ["10.20.2.0/24", "10.20.3.0/24"]
    error_message = "private_subnet_cidrs must expose the cache's private subnets for the root's replication_ingress_cidrs"
  }
  assert {
    condition     = aws_service_discovery_service.tier.health_check_custom_config[0].failure_threshold == 1
    error_message = "failure_threshold = 1 must stay for upgrade safety"
  }
}

run "regional_cache_41340_narrowed_to_write_tier_subnets" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_replication_cidrs  = ["10.10.2.0/24", "10.10.3.0/24"]
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
  }

  assert {
    condition = (
      toset([for r in aws_vpc_security_group_ingress_rule.write_region_replication_udp : r.cidr_ipv4]) == toset(["10.10.2.0/24", "10.10.3.0/24"]) &&
      toset([for r in aws_vpc_security_group_egress_rule.write_region_replication_udp : r.cidr_ipv4]) == toset(["10.10.2.0/24", "10.10.3.0/24"])
    )
    error_message = "41340/udp rules must use only the write tier's subnet CIDRs"
  }
  assert {
    condition     = length([for r in aws_vpc_security_group_ingress_rule.write_region_replication_udp : r if r.cidr_ipv4 == "10.10.0.0/16"]) == 0
    error_message = "The whole write VPC must not be allowed on 41340 once narrowed"
  }
}

run "regional_cache_41340_rejects_open_internet" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_replication_cidrs  = ["0.0.0.0/0"]
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
  }

  expect_failures = [var.write_tier_replication_cidrs]
}

run "replication_port_requires_client_certificates" {
  command = plan

  variables {
    replication_ingress_cidrs = ["10.20.2.0/24", "10.20.3.0/24"]
    trusted_ca_pem            = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
  }

  assert {
    condition = (
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__QUIC_INTERNAL__VERIFY_CLIENT_CERTS"]) == "true" &&
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__QUIC_INTERNAL__CERTIFICATE__CERT_FILE"]) == "/certs/server.crt" &&
      one([for e in module.compute.listener_env_vars : e.value if e.name == "LORE__SERVER__QUIC_INTERNAL__CERTIFICATE__CERT_CHAIN"]) == "/etc/lore/overlay/replication-ca-bundle.pem"
    )
    error_message = "Every active 41340 listener must require a client certificate and configured trust bundle"
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.replication_quic) == 1 && aws_vpc_security_group_ingress_rule.replication_quic[0].ip_protocol == "udp"
    error_message = "The same-VPC replication rule must expose only QUIC over UDP"
  }
  assert {
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__SERVER__GRPC_INTERNAL__ENABLED"]) == "false"
    error_message = "The unused internal gRPC/TCP listener must remain explicitly disabled"
  }
  assert {
    condition     = output.private_subnet_cidrs == ["10.0.2.0/24", "10.0.3.0/24"]
    error_message = "Root must expose its private subnet CIDRs for a regional cache's write_tier_replication_cidrs"
  }
  assert {
    condition     = output.auth_jwk_endpoint == null && output.auth_jwt_issuer == null
    error_message = "No auth outputs when auth_mode = none"
  }
  assert {
    condition     = aws_service_discovery_service.write_tier.health_check_custom_config[0].failure_threshold == 1
    error_message = "failure_threshold = 1 must stay for upgrade safety"
  }
}

run "cross_region_replication_requires_peer_ca" {
  command = plan

  variables {
    replication_ingress_cidrs = ["10.20.2.0/24"]
    trusted_ca_pem            = null
  }

  expect_failures = [var.trusted_ca_pem]
}

run "root_exposes_external_auth_for_a_regional_cache" {
  command = plan

  variables {
    auth_mode         = "external"
    auth_jwk_endpoint = "https://login.example.com/.well-known/jwks.json"
    auth_jwt_issuer   = "https://login.example.com"
    auth_jwt_audience = ["lore-server"]
  }

  assert {
    condition     = output.auth_jwk_endpoint == "https://login.example.com/.well-known/jwks.json" && output.auth_jwt_issuer == "https://login.example.com"
    error_message = "Root must expose the effective JWK endpoint and issuer"
  }
}

# =============================================================================
# Route ownership — pin the exact declared route sets (no safe in-place migration exists)
# =============================================================================

run "route_tables_declare_exactly_the_expected_routes" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  override_resource {
    target          = aws_nat_gateway.this
    override_during = plan
    values          = { id = "nat-0123456789abcdef0" }
  }
  override_resource {
    target          = aws_internet_gateway.this
    override_during = plan
    values          = { id = "igw-0123456789abcdef0" }
  }

  variables {
    vpc_cidr           = "10.10.0.0/16"
    name_prefix        = "lore-dev"
    availability_zones = ["us-east-2a", "us-east-2b"]
    peering_routes = [{
      cidr_block                = "10.20.0.0/16"
      vpc_peering_connection_id = "pcx-0123456789abcdef0"
    }]
  }

  assert {
    condition     = length(aws_route_table.private.route) == 2
    error_message = "Private route table must declare exactly the NAT default route and the declared peering routes"
  }
  assert {
    condition     = toset([for r in aws_route_table.private.route : r.cidr_block]) == toset(["0.0.0.0/0", "10.20.0.0/16"])
    error_message = "Private route table destinations changed; review the route ownership note before changing them"
  }
  assert {
    condition     = one([for r in aws_route_table.private.route : r.vpc_peering_connection_id if r.cidr_block == "10.20.0.0/16"]) == "pcx-0123456789abcdef0"
    error_message = "Peering route must target the declared peering connection"
  }
  assert {
    condition     = length(aws_route_table.public.route) == 1 && one(aws_route_table.public.route).cidr_block == "0.0.0.0/0"
    error_message = "Public route table must declare exactly the internet gateway default route"
  }
  assert {
    condition     = output.private_subnet_cidrs == ["10.10.2.0/24", "10.10.3.0/24"]
    error_message = "private_subnet_cidrs must list the private subnets"
  }
}

run "route_tables_without_peering_keep_only_defaults" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  override_resource {
    target          = aws_nat_gateway.this
    override_during = plan
    values          = { id = "nat-0123456789abcdef0" }
  }
  override_resource {
    target          = aws_internet_gateway.this
    override_during = plan
    values          = { id = "igw-0123456789abcdef0" }
  }

  variables {
    vpc_cidr           = "10.10.0.0/16"
    name_prefix        = "lore-dev"
    availability_zones = ["us-east-2a", "us-east-2b"]
  }

  assert {
    condition     = length(aws_route_table.private.route) == 1 && one(aws_route_table.private.route).cidr_block == "0.0.0.0/0"
    error_message = "Single-region private route table must declare only the NAT default route"
  }
}

run "regional_cache_rejects_open_client_and_write_region_ingress" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["0.0.0.0/0"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "0.0.0.0/0"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
  }

  expect_failures = [var.allowed_ingress_cidrs, var.write_region_vpc_cidr]
}

# =============================================================================
# DynamoDB interface endpoint — private branch-pointer and lock path over VPC peering
# =============================================================================

run "dynamodb_interface_endpoint_scoped_to_cache_cidrs" {
  command = plan

  variables {
    dynamodb_endpoint_client_cidrs = ["10.20.2.0/24", "10.20.3.0/24"]
  }

  assert {
    condition     = length(aws_vpc_endpoint.dynamodb_interface) == 1
    error_message = "The write VPC must create one DynamoDB interface endpoint"
  }

  assert {
    condition = (
      aws_vpc_endpoint.dynamodb_interface[0].vpc_endpoint_type == "Interface" &&
      aws_vpc_endpoint.dynamodb_interface[0].private_dns_enabled == false &&
      aws_vpc_endpoint.dynamodb_interface[0].ip_address_type == "ipv4"
    )
    error_message = "The DynamoDB endpoint must use private IPv4 ENIs without private DNS"
  }

  assert {
    condition = (
      toset([for rule in aws_vpc_security_group_ingress_rule.dynamodb_interface_endpoint_https : rule.cidr_ipv4]) == toset(["10.20.2.0/24", "10.20.3.0/24"]) &&
      alltrue([for rule in aws_vpc_security_group_ingress_rule.dynamodb_interface_endpoint_https : rule.from_port == 443 && rule.to_port == 443 && rule.ip_protocol == "tcp"])
    )
    error_message = "Only the cache private subnets may reach the endpoint on HTTPS"
  }

  assert {
    condition     = length(local.dynamodb_interface_endpoint_actions) == 7 && !contains(local.dynamodb_interface_endpoint_actions, "dynamodb:*")
    error_message = "The endpoint policy action list must stay limited to Lore's seven DynamoDB calls"
  }

  assert {
    condition     = toset(local.dynamodb_interface_endpoint_index_actions) == toset(["dynamodb:Query"])
    error_message = "The lock index endpoint policy must allow Query only"
  }
}

run "dynamodb_interface_endpoint_rejects_open_internet" {
  command = plan

  variables {
    dynamodb_endpoint_client_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.dynamodb_endpoint_client_cidrs]
}

run "dynamodb_interface_endpoint_supports_existing_vpc" {
  command = plan

  variables {
    vpc_id                         = "vpc-0123456789abcdef0"
    private_subnet_ids             = ["subnet-private-a", "subnet-private-b"]
    public_subnet_ids              = ["subnet-public-a", "subnet-public-b"]
    dynamodb_endpoint_client_cidrs = ["10.20.2.0/24", "10.20.3.0/24"]
    dynamodb_endpoint_subnet_ids   = ["subnet-endpoint-a", "subnet-endpoint-b"]
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 0 && length(aws_vpc_endpoint.dynamodb) == 0
    error_message = "Existing VPCs must not gain module-managed gateway endpoints"
  }

  assert {
    condition     = toset(aws_vpc_endpoint.dynamodb_interface[0].subnet_ids) == toset(["subnet-endpoint-a", "subnet-endpoint-b"])
    error_message = "Existing VPC callers must be able to select one endpoint subnet per Availability Zone"
  }
}

run "regional_cache_rejects_dynamodb_endpoint_in_another_region" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    dynamodb_endpoint_url         = "https://vpce-0123456789abcdef0-abc123.dynamodb.us-west-2.vpce.amazonaws.com"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
  }

  expect_failures = [var.dynamodb_endpoint_url]
}

run "regional_cache_rejects_non_aws_dynamodb_endpoint_host" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    dynamodb_endpoint_url         = "https://vpce-0123456789abcdef0-abc123.dynamodb.us-east-2.vpce.amazonaws.com.attacker.example"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
  }

  expect_failures = [var.dynamodb_endpoint_url]
}

run "dynamodb_interface_endpoint_exports_regional_dns" {
  command = plan

  variables {
    dynamodb_endpoint_client_cidrs = ["10.20.2.0/24"]
  }

  override_resource {
    target          = aws_vpc_endpoint.dynamodb_interface
    override_during = plan
    values = {
      id = "vpce-0123456789abcdef0"
      dns_entry = [
        {
          dns_name       = "vpce-0123456789abcdef0-abc123.dynamodb.us-east-2.vpce.amazonaws.com"
          hosted_zone_id = "Z0123456789"
        },
        {
          dns_name       = "vpce-0123456789abcdef0-abc123-us-east-2a.dynamodb.us-east-2.vpce.amazonaws.com"
          hosted_zone_id = "Z0123456789"
        },
      ]
    }
  }

  assert {
    condition     = output.dynamodb_interface_endpoint_url == "https://vpce-0123456789abcdef0-abc123.dynamodb.us-east-2.vpce.amazonaws.com"
    error_message = "The output must choose the regional endpoint DNS entry, not a zonal entry"
  }
}

run "regional_cache_custom_mtls_requires_all_five_secrets" {
  command = plan

  module {
    source = "./modules/regional-cache"
  }

  variables {
    name_prefix                   = "lore-dev-london"
    environment                   = "dev"
    container_image               = "123456789012.dkr.ecr.us-west-2.amazonaws.com/loreserver:v0.12.0"
    allowed_ingress_cidrs         = ["10.20.0.0/16"]
    vpc_cidr                      = "10.20.0.0/16"
    write_region                  = "us-east-2"
    write_region_vpc_cidr         = "10.10.0.0/16"
    write_tier_dns_name           = "write-tier.lore-dev.internal"
    write_tier_ca_certificate_pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----"
    mutable_store_table_name      = "lore-dev-mutable-typed-store"
    mutable_store_table_arn       = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-mutable-typed-store"
    locks_table_name              = "lore-dev-locks"
    locks_table_arn               = "arn:aws:dynamodb:us-east-2:123456789012:table/lore-dev-locks"
    tls_certificate_secret_arn    = "arn:aws:secretsmanager:us-west-2:123456789012:secret:server-cert"
  }

  expect_failures = [var.tls_certificate_secret_arn]
}
