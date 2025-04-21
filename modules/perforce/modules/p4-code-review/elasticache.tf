# Subnet Group for Horde Elasticache
resource "aws_elasticache_subnet_group" "subnet_group" {
  count      = var.existing_redis_connection != null ? 0 : 1
  name       = "${local.name_prefix}-elasticache-subnet-group"
  subnet_ids = var.subnets
}

# Single Node Elasticache Cluster for P4 Code Review
resource "aws_elasticache_cluster" "cluster" {
  count                = var.existing_redis_connection != null ? 0 : 1
  cluster_id           = "${local.name_prefix}-elasticache-redis-cluster"
  engine               = "redis"
  node_type            = var.elasticache_node_type
  num_cache_nodes      = var.elasticache_node_count
  parameter_group_name = local.elasticache_redis_parameter_group_name
  engine_version       = local.elasticache_redis_engine_version
  port                 = local.elasticache_redis_port
  security_group_ids   = [aws_security_group.elasticache[0].id]
  subnet_group_name    = aws_elasticache_subnet_group.subnet_group[0].name

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-elasticache-redis-cluster"
    }
  )
}
