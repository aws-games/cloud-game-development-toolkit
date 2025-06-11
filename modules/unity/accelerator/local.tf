locals {
  name_prefix = "unity-accelerator"

  tags = merge(var.tags, {
    "environment" = var.environment
  })

  # Load balancer subnets map for NLB ingress rules
  lb_subnet_map = {
    for idx, subnet_id in var.lb_subnets :
    format("subnet_%d", idx) => subnet_id
  }

  # EFS information
  efs_file_system_id  = var.efs_id != null ? var.efs_id : aws_efs_file_system.unity_accelerator_efs[0].id
  efs_file_system_arn = var.efs_id != null ? data.aws_efs_file_system.efs_file_system[0].arn : aws_efs_file_system.unity_accelerator_efs[0].arn
  efs_access_point_id = var.efs_access_point_id != null ? var.efs_access_point_id : aws_efs_access_point.unity_accelerator_efs_data_access_point[0].id

  # Unity Accelerator environment variables
  base_env = [
    {
      name  = "UNITY_ACCELERATOR_DEBUG"
      value = "true"
    },
    {
      name  = "UNITY_ACCELERATOR_AUTO_UPDATES"
      value = "false"
    },
    {
      name  = "UNITY_ACCELERATOR_PERSIST"
      value = var.unity_accelerator_persist
    },
    {
      name  = "UNITY_ACCELERATOR_LOG_STDOUT"
      value = var.unity_accelerator_log_stdout
    },
    {
      name  = "USER"
      value = var.unity_accelerator_dashboard_username
    }
  ]

  # Unity Accelerator dashboard password environment variable if provided
  password_env = var.unity_accelerator_dashboard_password != null ? [
    {
      name  = "PASSWORD"
      value = var.unity_accelerator_dashboard_password
    }
  ] : []

}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Data source to look up existing EFS file system if ID is provided
data "aws_efs_file_system" "efs_file_system" {
  count          = var.efs_id != null ? 1 : 0
  file_system_id = var.efs_id
}
