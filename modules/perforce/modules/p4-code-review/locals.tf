locals {
  image            = "perforce/helix-swarm" # cannot change this until the Perforce Helix Swarm Image is updated to use the new naming for P4 Code Review
  name_prefix      = "${var.project_prefix}-${var.name}"
  data_volume_name = "helix-swarm-data"         # cannot change this until the Perforce Helix Swarm Image is updated to use the new naming for P4 Code Review
  data_path        = "/opt/perforce/swarm/data" # cannot change this until the Perforce Helix Swarm Image is updated to use the new naming for P4 Code Review

  elasticache_redis_port                 = 6379
  elasticache_redis_engine_version       = "7.0"
  elasticache_redis_parameter_group_name = "default.redis7"

}
