
################################################################################
# Filesystem
################################################################################

# File system for Helix Swarm
resource "aws_efs_file_system" "helix_swarm_efs_file_system" {
  count            = var.enable_elastic_filesystem ? 1 : 0
  creation_token   = "${local.name_prefix}-efs-file-system"
  performance_mode = var.helix_swarm_efs_performance_mode
  throughput_mode  = var.helix_swarm_efs_throughput_mode

  #TODO: Parameterize encryption and customer managed key creation
  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
  #checkov:skip=CKV_AWS_184: CMK encryption not supported currently
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-file-system"
  })
}

# Mount targets for Helix Swarm containers
resource "aws_efs_mount_target" "helix_swarm_efs_mount_target" {
  count           = var.enable_elastic_filesystem ? length(var.helix_swarm_service_subnets) : 0
  file_system_id  = aws_efs_file_system.helix_swarm_efs_file_system[0].id
  subnet_id       = var.helix_swarm_service_subnets[count.index]
  security_groups = [aws_security_group.helix_swarm_efs_security_group[0].id]
}

# Helix Swarm Home directory access point
resource "aws_efs_access_point" "helix_swarm_efs_access_point" {
  count          = var.enable_elastic_filesystem ? 1 : 0
  file_system_id = aws_efs_file_system.helix_swarm_efs_file_system[0].id
  posix_user {
    gid = 0
    uid = 0
  }
  root_directory {
    path = local.helix_swarm_config_path
    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = 755
    }
  }
  tags = local.tags
}

# Helix Swarm Redis data access point
resource "aws_efs_access_point" "redis_efs_access_point" {
  count          = var.enable_elastic_filesystem ? 1 : 0
  file_system_id = aws_efs_file_system.helix_swarm_efs_file_system[0].id
  posix_user {
    gid = 1001
    uid = 1001
  }
  root_directory {
    path = local.helix_swarm_redis_data_path
    creation_info {
      owner_gid   = 1001
      owner_uid   = 1001
      permissions = 755
    }
  }
  tags = local.tags
}
