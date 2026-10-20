# =============================================================================
# DynamoDB — Metadata, branches, locks
# =============================================================================

resource "aws_dynamodb_table" "fragments" {
  #checkov:skip=CKV_AWS_119: AWS-managed encryption (default) sufficient — KMS CMK adds cost with no security benefit for content-addressed data
  count = var.create_immutable_tables ? 1 : 0

  name         = "${var.name_prefix}-fragments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "hash"
  range_key    = "repository_context"

  attribute {
    name = "hash"
    type = "B"
  }
  attribute {
    name = "repository_context"
    type = "B"
  }

  # Global Table replicas (optional, immutable rows only). Streams are a Global Tables requirement.
  stream_enabled   = length(var.immutable_table_replica_regions) > 0 ? true : null
  stream_view_type = length(var.immutable_table_replica_regions) > 0 ? "NEW_AND_OLD_IMAGES" : null

  dynamic "replica" {
    for_each = toset(var.immutable_table_replica_regions)
    content {
      region_name            = replica.value
      point_in_time_recovery = true
    }
  }

  point_in_time_recovery { enabled = true }
  deletion_protection_enabled = var.enable_deletion_protection

  tags = merge(var.tags, { Name = "${var.name_prefix}-fragments" })
}

resource "aws_dynamodb_table" "fragment_metadata" {
  #checkov:skip=CKV_AWS_119: AWS-managed encryption (default) sufficient — KMS CMK adds cost with no security benefit for metadata
  count = var.create_immutable_tables ? 1 : 0

  name         = "${var.name_prefix}-fragment-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "hash"

  attribute {
    name = "hash"
    type = "B"
  }

  # Global Table replicas (optional, immutable rows only). Streams are a Global Tables requirement.
  stream_enabled   = length(var.immutable_table_replica_regions) > 0 ? true : null
  stream_view_type = length(var.immutable_table_replica_regions) > 0 ? "NEW_AND_OLD_IMAGES" : null

  dynamic "replica" {
    for_each = toset(var.immutable_table_replica_regions)
    content {
      region_name            = replica.value
      point_in_time_recovery = true
    }
  }

  point_in_time_recovery { enabled = true }
  deletion_protection_enabled = var.enable_deletion_protection

  tags = merge(var.tags, { Name = "${var.name_prefix}-fragment-metadata" })
}

resource "aws_dynamodb_table" "mutable_store" {
  #checkov:skip=CKV_AWS_119: AWS-managed encryption (default) sufficient — KMS CMK adds cost with no security benefit for branch state
  count = var.create_mutable_tables ? 1 : 0

  name         = "${var.name_prefix}-mutable-typed-store"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "repository_id"
  range_key    = "key"

  attribute {
    name = "repository_id"
    type = "B"
  }
  attribute {
    name = "key"
    type = "B"
  }

  point_in_time_recovery { enabled = true }
  deletion_protection_enabled = var.enable_deletion_protection

  tags = merge(var.tags, { Name = "${var.name_prefix}-mutable-typed-store" })
}

resource "aws_dynamodb_table" "locks" {
  #checkov:skip=CKV_AWS_119: AWS-managed encryption (default) sufficient — KMS CMK adds cost with no security benefit for lock metadata
  count = var.create_mutable_tables ? 1 : 0

  name         = "${var.name_prefix}-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "hash"
  range_key    = "repositoryBranch"

  attribute {
    name = "hash"
    type = "B"
  }
  attribute {
    name = "repositoryBranch"
    type = "B"
  }
  attribute {
    name = "ownerId"
    type = "S"
  }
  attribute {
    name = "repository"
    type = "B"
  }
  attribute {
    name = "branch"
    type = "B"
  }
  attribute {
    name = "description"
    type = "S"
  }

  global_secondary_index {
    name            = "owner-repo-branch"
    hash_key        = "ownerId"
    range_key       = "repositoryBranch"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "repo-branch"
    hash_key        = "repository"
    range_key       = "branch"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "repo-branch-description"
    hash_key        = "repositoryBranch"
    range_key       = "description"
    projection_type = "ALL"
  }

  point_in_time_recovery { enabled = true }
  deletion_protection_enabled = var.enable_deletion_protection

  tags = merge(var.tags, { Name = "${var.name_prefix}-locks" })
}
