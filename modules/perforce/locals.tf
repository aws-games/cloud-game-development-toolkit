locals {
  # shared ECS cluster configuration
  shared_ecs_cluster        = var.p4_code_review_config != null && var.p4_auth_config != null
  create_shared_ecs_cluster = var.existing_ecs_cluster_name == null && local.shared_ecs_cluster

  # shared ALB configuration
  shared_alb = var.p4_code_review_config != null && var.p4_auth_config != null
  create_shared_alb = (local.shared_alb ?
    var.p4_auth_config.create_application_load_balancer &&
  var.p4_code_review_config.create_application_load_balancer : false)
}
