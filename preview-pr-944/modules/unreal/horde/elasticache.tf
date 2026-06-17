# Subnet Group for Horde Elasticache
resource "aws_elasticache_subnet_group" "horde" {
  count      = var.custom_cache_connection_config == null ? 1 : 0
  name       = "${var.name}-elasticache-subnet-group"
  subnet_ids = var.unreal_horde_service_subnets
}

# Single Node Elasticache Cluster for Horde
resource "aws_elasticache_cluster" "horde" {
  count                = var.elasticache_engine == "redis" && var.custom_cache_connection_config == null ? 1 : 0
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
  count                      = var.elasticache_engine == "valkey" && var.custom_cache_connection_config == null ? 1 : 0
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
