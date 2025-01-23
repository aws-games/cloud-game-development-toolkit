################################################################################
# Filesystem
################################################################################

# File system for Perforce Helix Swarm
resource "aws_efs_file_system" "helix_swarm" {
  creation_token   = "${local.name_prefix}-efs-file-system"
  performance_mode = var.elastic_filesystem_performance_mode
  throughput_mode  = var.elastic_filesystem_throughput_mode

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
resource "aws_efs_mount_target" "helix_swarm" {
  count           = length(var.helix_swarm_service_subnets)
  file_system_id  = aws_efs_file_system.helix_swarm.id
  subnet_id       = var.helix_swarm_service_subnets[count.index]
  security_groups = [aws_security_group.swarm_efs.id]
}

# Swarm Home directory access point
resource "aws_efs_access_point" "helix_swarm" {
  #checkov:skip=CKV_AWS_330: Posix user access not scoped by design
  file_system_id = aws_efs_file_system.helix_swarm.id
  root_directory {
    path = "/opt/perforce/swarm/efs"
    creation_info {
      owner_gid   = 33
      owner_uid   = 33
      permissions = 755
    }
  }
  tags = local.tags
}

resource "aws_efs_backup_policy" "helix_swarm" {
  count          = var.enable_default_efs_backup_plan ? 1 : 0
  file_system_id = aws_efs_file_system.helix_swarm.id

  backup_policy {
    status = "ENABLED"
  }
}
