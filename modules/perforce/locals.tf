locals {
  # shared ECS cluster configuration
  create_shared_ecs_cluster = (var.existing_ecs_cluster_name == null &&
  (var.p4_auth_config != null || var.p4_code_review_config != null))

  # This serves as a sensible default for p4d_port config options
  p4_port = var.p4_server_config != null ? (
    "%{if !var.p4_server_config.plaintext}ssl:%{endif}${var.p4_server_config.fully_qualified_domain_name}:1666"
  ) : null
}
