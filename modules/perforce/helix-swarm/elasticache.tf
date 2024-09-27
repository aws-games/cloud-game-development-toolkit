# Subnet Group for Horde Elasticache
resource "aws_elasticache_subnet_group" "swarm" {
  count      = var.existing_redis_connection != null ? 0 : 1
  name       = "${var.name}-elasticache-subnet-group"
  subnet_ids = var.helix_swarm_service_subnets
}

# Single Node Elasticache Cluster for Helix Swarm
resource "aws_elasticache_cluster" "swarm" {
  count                = var.existing_redis_connection != null ? 0 : 1
  cluster_id           = "${var.name}-elasticache-redis-cluster"
  engine               = "redis"
  node_type            = var.elasticache_node_type
  num_cache_nodes      = var.elasticache_node_count
  parameter_group_name = local.elasticache_redis_parameter_group_name
  engine_version       = local.elasticache_redis_engine_version
  port                 = local.elasticache_redis_port
  security_group_ids   = [aws_security_group.helix_swarm_elasticache_sg[0].id]
  subnet_group_name    = aws_elasticache_subnet_group.swarm[0].name
}
