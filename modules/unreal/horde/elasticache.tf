# Subnet Group for Horde Elasticache
resource "aws_elasticache_subnet_group" "horde" {
  count      = var.custom_cache_connection_config == null && !var.elasticache_serverless ? 1 : 0
  name       = "${var.name}-elasticache-subnet-group"
  subnet_ids = var.unreal_horde_service_subnets
}

# Serverless Elasticache deployment
resource "aws_elasticache_serverless_cache" "horde" {
  count = var.elasticache_serverless ? 1 : 0

  name                 = "${var.project_prefix}-${var.name}-elasticache"
  description          = "Elasticache deployment for Unreal Horde"
  engine               = var.elasticache_engine
  major_engine_version = var.elasticache_engine == "redis" ? var.elasticache_redis_engine_version : var.elasticache_valkey_engine_version

  security_group_ids = [aws_security_group.unreal_horde_elasticache_sg[0].id]
  subnet_ids         = var.unreal_horde_service_subnets

  cache_usage_limits {
    data_storage {
      unit    = "GB"
      minimum = var.elasticache_serverless_usesage_limits.data_storage.minimum
      maximum = var.elasticache_serverless_usesage_limits.data_storage.maximum
    }
    ecpu_per_second {
      minimum = var.elasticache_serverless_usesage_limits.ecpu_per_second.minimum
      maximum = var.elasticache_serverless_usesage_limits.ecpu_per_second.maximum
    }
  }
}

# Single Node Elasticache Cluster for Horde
resource "aws_elasticache_cluster" "horde" {
  count                = !var.elasticache_serverless && var.elasticache_engine == "redis" && var.custom_cache_connection_config == null ? 1 : 0
  cluster_id           = "${var.name}-elasticache-redis-cluster"
  engine               = "redis"
  node_type            = var.elasticache_node_type
  num_cache_nodes      = var.elasticache_node_count
  parameter_group_name = var.elasticache_redis_parameter_group_name
  engine_version       = var.elasticache_redis_engine_version
  port                 = var.elasticache_port
  security_group_ids   = [aws_security_group.unreal_horde_elasticache_sg[0].id]
  subnet_group_name    = aws_elasticache_subnet_group.horde[0].name

  snapshot_retention_limit = var.elasticache_snapshot_retention_limit
}

# Valkey with Cluster Mode Disabled
resource "aws_elasticache_replication_group" "horde" {
  automatic_failover_enabled = true
  count                      = !var.elasticache_serverless && var.elasticache_engine == "valkey" && var.custom_cache_connection_config == null ? 1 : 0
  engine                     = "valkey"
  engine_version             = var.elasticache_valkey_engine_version
  replication_group_id       = "${var.name}-elasticache-valkey-rep-grp"
  description                = "Valkey for Unreal Engine Horde"
  node_type                  = var.elasticache_node_type
  num_cache_clusters         = var.elasticache_cluster_count
  parameter_group_name       = var.elasticache_valkey_parameter_group_name
  port                       = var.elasticache_port
  security_group_ids         = [aws_security_group.unreal_horde_elasticache_sg[0].id]
  subnet_group_name          = aws_elasticache_subnet_group.horde[0].name
}
