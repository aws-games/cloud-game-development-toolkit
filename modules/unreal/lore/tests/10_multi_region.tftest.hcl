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
    condition     = length(aws_vpc_security_group_ingress_rule.replication_cidr_grpc) == 0 && length(aws_vpc_security_group_egress_rule.replication_cidr_udp) == 0
    error_message = "No CIDR replication rules without replication_ingress_cidrs"
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
}

# =============================================================================
# CIDR ingress/egress for tiers across inter-region peering
# =============================================================================

run "replication_cidrs_open_four_rules_each_way" {
  command = plan

  variables {
    replication_ingress_cidrs = ["10.20.0.0/16", "10.30.0.0/16"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.replication_cidr_grpc) == 2 && length(aws_vpc_security_group_ingress_rule.replication_cidr_quic) == 2 && length(aws_vpc_security_group_ingress_rule.replication_cidr_tcp) == 2 && length(aws_vpc_security_group_ingress_rule.replication_cidr_udp) == 2
    error_message = "One ingress rule per CIDR for 41337/tcp, 41337/udp, 41340/tcp and 41340/udp"
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.replication_cidr_grpc) == 2 && length(aws_vpc_security_group_egress_rule.replication_cidr_tcp) == 2 && length(aws_vpc_security_group_egress_rule.replication_cidr_udp) == 2
    error_message = "Matching egress rules so the write tier can replicate to the peer"
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.replication_cidr_udp["10.20.0.0/16"].from_port == 41340 && aws_vpc_security_group_ingress_rule.replication_cidr_udp["10.20.0.0/16"].ip_protocol == "udp"
    error_message = "Replication QUIC rule must be 41340/udp"
  }
}

run "replication_cidrs_reject_open_internet" {
  command = plan

  variables {
    replication_ingress_cidrs = ["0.0.0.0/0"]
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
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__REMOTE_URL"]) == "lore://write-tier.lore-dev.internal:41340"
    error_message = "Durable remote must be the write tier's replication endpoint"
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
    condition     = output.cache_dns_name == "regional-cache.lore-dev-london.internal"
    error_message = "cache_dns_name"
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.write_region_replication_udp.from_port == 41340 && aws_vpc_security_group_ingress_rule.write_region_replication_udp.cidr_ipv4 == "10.10.0.0/16"
    error_message = "The write tier must be able to push into the cache on 41340/udp"
  }
}

run "regional_cache_can_forward_branch_pointers_to_the_write_tier" {
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
