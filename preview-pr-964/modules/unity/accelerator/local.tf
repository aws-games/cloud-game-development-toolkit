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

  # Unity Accelerator dashboard variables
  # Will hold the ARN of the Secrets Manager secrets containing the username and password, whether they were provided by user or created through the flow
  dashboard_username_secret = var.unity_accelerator_dashboard_username_arn == null ? awscc_secretsmanager_secret.dashboard_username_arn[0].secret_id : var.unity_accelerator_dashboard_username_arn
  dashboard_password_secret = var.unity_accelerator_dashboard_password_arn == null ? awscc_secretsmanager_secret.dashboard_password_arn[0].secret_id : var.unity_accelerator_dashboard_password_arn

  # Unity Accelerator environment variables
  base_env = [
    {
      name  = "UNITY_ACCELERATOR_DEBUG"
      value = var.unity_accelerator_debug_mode
    },
    {
      name  = "UNITY_ACCELERATOR_AUTO_UPDATES"
      value = "false"
    },
    {
      name  = "UNITY_ACCELERATOR_PERSIST"
      value = "/agent"
    },
    {
      name  = "UNITY_ACCELERATOR_LOG_STDOUT"
      value = var.unity_accelerator_log_stdout
    }
  ]
}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Data source to look up existing EFS file system if ID is provided
data "aws_efs_file_system" "efs_file_system" {
  count          = var.efs_id != null ? 1 : 0
  file_system_id = var.efs_id
}
