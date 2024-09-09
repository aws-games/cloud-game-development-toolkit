resource "aws_elasticache_serverless_cache" "horde" {
  engine = "redis"
  name   = "${var.name}-elasticache-redis"
  cache_usage_limits {
    data_storage {
      maximum = 10
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 5000
    }
  }
  daily_snapshot_time  = var.elasticache_daily_snapshot_time
  description          = "Horde Elasticache Redis"
  major_engine_version = "7"
  security_group_ids   = [aws_security_group.unreal_horde_elasticache_sg.id]
  subnet_ids           = var.unreal_horde_subnets
}
