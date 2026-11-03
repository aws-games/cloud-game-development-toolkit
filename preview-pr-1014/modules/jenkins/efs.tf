################################################################################
# Filesystem
################################################################################

# File system for Jenkins
resource "aws_efs_file_system" "jenkins_efs_file_system" {
  creation_token   = "${local.name_prefix}-efs-file-system"
  performance_mode = var.jenkins_efs_performance_mode
  throughput_mode  = var.jenkins_efs_throughput_mode

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

# Mount targets for Jenkins containers
resource "aws_efs_mount_target" "jenkins_efs_mount_target" {
  count           = length(var.jenkins_service_subnets)
  file_system_id  = aws_efs_file_system.jenkins_efs_file_system.id
  subnet_id       = var.jenkins_service_subnets[count.index]
  security_groups = [aws_security_group.jenkins_efs_security_group.id]
}

# Jenkins Home directory access point
resource "aws_efs_access_point" "jenkins_efs_access_point" {
  file_system_id = aws_efs_file_system.jenkins_efs_file_system.id
  posix_user {
    gid = 1001
    uid = 1001
  }
  root_directory {
    path = local.jenkins_home_path
    creation_info {
      owner_gid   = 1001
      owner_uid   = 1001
      permissions = 755
    }
  }
  tags = local.tags
}

resource "aws_efs_backup_policy" "policy" {
  count          = var.enable_default_efs_backup_plan ? 1 : 0
  file_system_id = aws_efs_file_system.jenkins_efs_file_system.id

  backup_policy {
    status = "ENABLED"
  }
}
