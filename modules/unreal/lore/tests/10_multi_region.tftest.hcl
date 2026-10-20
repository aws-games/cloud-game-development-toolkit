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
    condition     = module.data.replication_role_arn == null
    error_message = "No S3 replication role without fragment_replication"
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
    condition     = one([for e in module.compute.store_env_vars : e.value if e.name == "LORE_CONFIG_PATH"]) == "/etc/lore/overlay"
    error_message = "Server must read the overlay directory where the topology file is written"
  }
}

# =============================================================================
# CIDR ingress/egress for tiers across inter-region peering
# =============================================================================

run "replication_cidrs_open_three_ports_each_way" {
  command = plan

  variables {
    replication_ingress_cidrs = ["10.20.0.0/16", "10.30.0.0/16"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.replication_cidr_grpc) == 2 && length(aws_vpc_security_group_ingress_rule.replication_cidr_tcp) == 2 && length(aws_vpc_security_group_ingress_rule.replication_cidr_udp) == 2
    error_message = "One ingress rule per CIDR for 41337/tcp, 41340/tcp and 41340/udp"
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
    condition     = strcontains(module.compute.topology_toml, "provider = \"fixed\"")
    error_message = "Overlay must select the fixed topology provider"
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
# Fragment replication (S3 CRR, optional Global Tables)
# =============================================================================

run "fragment_replication_creates_crr_without_global_tables" {
  command = plan

  variables {
    fragment_replication = {
      destination_bucket_arn = "arn:aws:s3:::lore-dev-replica-fragments-abc123"
    }
  }

  assert {
    condition     = module.data.replication_summary.enabled
    error_message = "CRR rule and role must exist"
  }
  assert {
    condition     = module.data.replication_summary.bucket_versioning == "Enabled"
    error_message = "CRR requires versioning"
  }
  assert {
    condition     = module.data.replication_summary.replication_time_control == false
    error_message = "RTC off by default"
  }
  assert {
    condition     = length(module.data.replication_summary.immutable_table_replica_regions) == 0
    error_message = "Global Tables are opt-in (rows can arrive before objects)"
  }
  assert {
    condition     = module.data.replication_summary.mutable_table_replica_regions == 0
    error_message = "Mutable store and locks are never replicated"
  }
}

run "fragment_replication_rtc_and_global_tables_opt_in" {
  command = plan

  variables {
    fragment_replication = {
      destination_bucket_arn   = "arn:aws:s3:::lore-dev-replica-fragments-abc123"
      replication_time_control = true
      global_tables_region     = "us-west-2"
    }
  }

  assert {
    condition     = module.data.replication_summary.replication_time_control == true
    error_message = "RTC rule must carry the 15-minute SLA"
  }
  assert {
    condition     = tolist(module.data.replication_summary.immutable_table_replica_regions) == tolist(["us-west-2"])
    error_message = "Both immutable tables gain exactly one replica"
  }
  assert {
    condition     = module.data.replication_summary.immutable_table_streams == true
    error_message = "Global Tables require streams"
  }
  assert {
    condition     = module.data.replication_summary.mutable_table_replica_regions == 0
    error_message = "Mutable store must stay single-region even with Global Tables on"
  }
}

run "versioning_stays_off_without_replication" {
  command = plan

  assert {
    condition     = module.data.replication_summary.bucket_versioning == "Disabled"
    error_message = "Fragments are immutable; versioning only when replicating"
  }
}

# =============================================================================
# Outputs a regional tier consumes
# =============================================================================

run "root_exposes_what_a_regional_tier_needs" {
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
    condition     = output.fragments_table_name == "lore-dev-fragments" && output.fragment_metadata_table_name == "lore-dev-fragment-metadata"
    error_message = "immutable table names"
  }
}
