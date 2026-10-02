locals {
  # Instance memory lookup (MiB). Covers common ECS instance types.
  # Reserve ~90% of instance memory for the container (OS + ECS agent + sidecars use the rest).
  instance_memory_map = {
    "t3.medium"     = 3072
    "t3.large"      = 6144
    "t3.xlarge"     = 13312
    "t3.2xlarge"    = 28672
    "m5.large"      = 6144
    "m5.xlarge"     = 13312
    "m5.2xlarge"    = 28672
    "c8gd.xlarge"   = 6144
    "c8gd.2xlarge"  = 13312
    "c8gd.4xlarge"  = 28672
    "c8gd.8xlarge"  = 59392
    "c8gd.12xlarge" = 88064
    "c8gd.16xlarge" = 118784
    "i3en.large"    = 13312
    "i3en.xlarge"   = 28672
    "i4i.large"     = 13312
    "i4i.xlarge"    = 28672
    "i4i.2xlarge"   = 59392
  }

  container_memory_reservation = coalesce(
    var.container_memory_reservation,
    lookup(local.instance_memory_map, var.instance_type, 28672)
  )

  # Instance store total capacity in bytes (from AWS docs).
  # Used to auto-size cache_max_size when var.cache_max_size_bytes = 0.
  instance_store_bytes = {
    "t3.medium"     = 0             # No instance store
    "t3.large"      = 0             # No instance store
    "t3.xlarge"     = 0             # No instance store
    "t3.2xlarge"    = 0             # No instance store
    "m5.large"      = 0             # No instance store
    "m5.xlarge"     = 0             # No instance store
    "m5.2xlarge"    = 0             # No instance store
    "c8gd.xlarge"   = 237000000000  # 237 GB (1× NVMe)
    "c8gd.2xlarge"  = 474000000000  # 474 GB (1× NVMe)
    "c8gd.4xlarge"  = 950000000000  # 950 GB (1× NVMe)
    "c8gd.8xlarge"  = 1900000000000 # 1.9 TB (1× NVMe)
    "c8gd.12xlarge" = 2850000000000 # 2.85 TB (3× NVMe)
    "c8gd.16xlarge" = 3800000000000 # 3.8 TB (2× NVMe)
    "i3en.large"    = 1250000000000 # 1.25 TB (1× NVMe)
    "i3en.xlarge"   = 2500000000000 # 2.5 TB (1× NVMe)
    "i3en.2xlarge"  = 5000000000000 # 5 TB (2× NVMe)
    "i4i.large"     = 468000000000  # 468 GB (1× NVMe)
    "i4i.xlarge"    = 937000000000  # 937 GB (1× NVMe)
    "i4i.2xlarge"   = 1875000000000 # 1.875 TB (1× NVMe)
    "i4i.4xlarge"   = 3750000000000 # 3.75 TB (2× NVMe)
    "r6id.xlarge"   = 237000000000  # 237 GB (1× NVMe)
    "r6id.2xlarge"  = 474000000000  # 474 GB (2× NVMe)
  }

  # 80% of total instance store, or explicit user override.
  # Falls back to 937 GB (i4i.xlarge default) for unknown instance types.
  cache_max_size = var.cache_max_size_bytes > 0 ? var.cache_max_size_bytes : (
    floor(lookup(local.instance_store_bytes, var.instance_type, 937000000000) * 0.8)
  )
}
