# Subnet Group for Horde Elasticache
resource "aws_elasticache_subnet_group" "horde" {
  count      = var.redis_connection_config == null ? 1 : 0
  name       = "${var.name}-elasticache-subnet-group"
  subnet_ids = var.unreal_horde_service_subnets
}

# Single Node Elasticache Cluster for Horde
resource "aws_elasticache_cluster" "horde" {
  count                = var.elasticache_engine == "redis" && var.redis_connection_config == null ? 1 : 0
  cluster_id           = "${var.name}-elasticache-redis-cluster"
  engine               = "redis"
  node_type            = var.elasticache_node_type
  num_cache_nodes      = var.elasticache_node_count
  parameter_group_name = local.elasticache_redis_parameter_group_name
  engine_version       = local.elasticache_redis_engine_version
  port                 = local.elasticache_port
  security_group_ids   = [aws_security_group.unreal_horde_elasticache_sg[0].id]
  subnet_group_name    = aws_elasticache_subnet_group.horde[0].name

  snapshot_retention_limit = var.elasticache_snapshot_retention_limit
}

# Valkey Cluster Mode Disabled
resource "aws_elasticache_replication_group" "horde" {
  count                = var.elasticache_engine == "valkey" && var.redis_connection_config == null ? 1 : 0
  engine               = "valkey"
  engine_version       = "7.2"
  replication_group_id = "${var.name}-elasticache-valkey-rep-grp"
  description          = "valkey for horde"
  node_type            = var.elasticache_node_type
  num_cache_clusters   = var.elasticache_cluster_count
  parameter_group_name = local.elasticache_valkey_parameter_group_name
  port                 = local.elasticache_port
  security_group_ids   = [aws_security_group.unreal_horde_elasticache_sg[0].id]
  subnet_group_name    = aws_elasticache_subnet_group.horde[0].name
}
