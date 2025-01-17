locals {
  helix_swarm_image     = "perforce/helix-swarm"
  name_prefix           = "${var.project_prefix}-${var.name}"
  helix_swarm_data_path = "/opt/perforce/swarm/data"

  elasticache_redis_port                 = 6379
  elasticache_redis_engine_version       = "7.0"
  elasticache_redis_parameter_group_name = "default.redis7"

  helix_swarm_sidecar_container_name = "helix-swarm-sidecar"

  tags = merge(var.tags, {
    "environment" = var.environment
  })
}
