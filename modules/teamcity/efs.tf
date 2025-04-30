# ################
# # TeamCity EFS #
# ################

# File system for teamcity
resource "aws_efs_file_system" "teamcity_efs_file_system" {
  count            = var.efs_id != null ? 0 : 1
  creation_token   = "${local.name_prefix}-efs-file-system"
  performance_mode = var.teamcity_efs_performance_mode
  throughput_mode  = var.teamcity_efs_throughput_mode

  encrypted = var.efs_encryption_enabled

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

# Mount Point for teamcity file system
resource "aws_efs_mount_target" "teamcity_efs_mount_target" {
  count          = var.efs_id != null ? 0 : length(var.service_subnets)
  file_system_id = var.efs_id != null ? var.efs_id : aws_efs_file_system.teamcity_efs_file_system[0].id
  subnet_id      = var.service_subnets[count.index]
  security_groups = [
    aws_security_group.teamcity_efs_sg[0].id
  ]
}

# TeamCity data directory
resource "aws_efs_access_point" "teamcity_efs_data_access_point" {
  count          = var.efs_access_point_id != null ? 0 : 1
  file_system_id = aws_efs_file_system.teamcity_efs_file_system[0].id
  posix_user {
    gid = 1000
    uid = 1000
  }
  root_directory {
    path = "/data/teamcity_server/datadir"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = 0755
    }
  }
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-efs-access-point"
  })
}