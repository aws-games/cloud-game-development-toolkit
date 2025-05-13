locals {
  # shared ECS cluster configuration
  create_shared_ecs_cluster = (var.existing_ecs_cluster_name == null &&
  (var.p4_auth_config != null || var.p4_code_review_config != null))
}
