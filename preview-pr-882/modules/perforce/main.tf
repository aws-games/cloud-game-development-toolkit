#################################################
# P4 Server (formerly Helix Core)
#################################################
module "p4_server" {
  source = "./modules/p4-server"
  count  = var.p4_server_config != null ? 1 : 0

  # General
  name           = var.p4_server_config.name
  project_prefix = var.p4_server_config.project_prefix
  environment    = var.p4_server_config.environment
  auth_service_url = (
    var.p4_server_config.auth_service_url != null ?
    var.p4_server_config.auth_service_url :
    (
      var.p4_auth_config != null ?
      (
        var.create_route53_private_hosted_zone ?
        "auth.${aws_route53_zone.perforce_private_hosted_zone[0].name}" :
        module.p4_auth[0].alb_dns_name
      ) :
      null
    )
  )
  fully_qualified_domain_name = var.p4_server_config.fully_qualified_domain_name

  # Compute
  instance_type         = var.p4_server_config.instance_type
  instance_architecture = var.p4_server_config.instance_architecture
  p4_server_type        = var.p4_server_config.p4_server_type
  unicode               = var.p4_server_config.unicode
  selinux               = var.p4_server_config.selinux
  case_sensitive        = var.p4_server_config.case_sensitive
  plaintext             = var.p4_server_config.plaintext

  # Storage
  storage_type         = var.p4_server_config.storage_type
  depot_volume_size    = var.p4_server_config.depot_volume_size
  metadata_volume_size = var.p4_server_config.metadata_volume_size
  logs_volume_size     = var.p4_server_config.logs_volume_size

  # FSxN
  protocol                          = var.p4_server_config.protocol
  amazon_fsxn_svm_id                = var.p4_server_config.amazon_fsxn_svm_id
  fsxn_filesystem_security_group_id = var.p4_server_config.fsxn_filesystem_security_group_id
  fsxn_svm_name                     = var.p4_server_config.fsxn_svm_name
  fsxn_password                     = var.p4_server_config.fsxn_password
  fsxn_region                       = var.p4_server_config.fsxn_region
  fsxn_management_ip                = var.p4_server_config.fsxn_management_ip

  # Networking & Security
  vpc_id                         = var.vpc_id
  instance_subnet_id             = var.p4_server_config.instance_subnet_id
  instance_private_ip            = var.p4_server_config.instance_private_ip
  create_default_sg              = var.p4_server_config.create_default_sg
  existing_security_groups       = var.p4_server_config.existing_security_groups
  internal                       = var.p4_server_config.internal
  super_user_password_secret_arn = var.p4_server_config.super_user_password_secret_arn
  super_user_username_secret_arn = var.p4_server_config.super_user_username_secret_arn
  create_default_role            = var.p4_server_config.create_default_role
  custom_role                    = var.p4_server_config.custom_role
}


#################################################
# P4Auth (formerly Perforce Helix Auth Service)
#################################################
module "p4_auth" {
  source = "./modules/p4-auth"
  count  = var.p4_auth_config != null ? 1 : 0

  # General
  name                            = var.p4_auth_config.name
  project_prefix                  = var.p4_auth_config.project_prefix
  enable_web_based_administration = var.p4_auth_config.enable_web_based_administration
  debug                           = var.p4_auth_config.debug
  fully_qualified_domain_name     = var.p4_auth_config.fully_qualified_domain_name

  # Compute
  cluster_name = (
    var.existing_ecs_cluster_name != null ?
    var.existing_ecs_cluster_name :
    aws_ecs_cluster.perforce_web_services_cluster[0].name
  )

  container_name   = var.p4_auth_config.container_name
  container_port   = var.p4_auth_config.container_port
  container_cpu    = var.p4_auth_config.container_cpu
  container_memory = var.p4_auth_config.container_memory
  p4d_port         = var.p4_auth_config.p4d_port != null ? var.p4_auth_config.p4d_port : local.p4_port

  # Storage & Logging
  enable_alb_access_logs           = false
  cloudwatch_log_retention_in_days = var.p4_auth_config.cloudwatch_log_retention_in_days

  # Networking & Security
  vpc_id  = var.vpc_id
  subnets = var.p4_auth_config.service_subnets

  create_application_load_balancer = false
  internal                         = var.p4_auth_config.internal
  create_default_role              = var.p4_auth_config.create_default_role
  custom_role                      = var.p4_auth_config.custom_role

  admin_username_secret_arn = var.p4_auth_config.admin_username_secret_arn
  admin_password_secret_arn = var.p4_auth_config.admin_password_secret_arn

  # SCIM
  p4d_super_user_arn          = var.p4_auth_config.p4d_super_user_arn
  p4d_super_user_password_arn = var.p4_auth_config.p4d_super_user_password_arn
  scim_bearer_token_arn       = var.p4_auth_config.scim_bearer_token_arn
  extra_env                   = var.p4_auth_config.extra_env

  depends_on = [aws_ecs_cluster.perforce_web_services_cluster[0]]
}


#################################################
# P4 Code Review (formerly Helix Swarm)
#################################################
module "p4_code_review" {
  source = "./modules/p4-code-review"
  count  = var.p4_code_review_config != null ? 1 : 0

  # General
  name                        = var.p4_code_review_config.name
  project_prefix              = var.p4_code_review_config.project_prefix
  debug                       = var.p4_code_review_config.debug
  fully_qualified_domain_name = var.p4_code_review_config.fully_qualified_domain_name

  cluster_name = (
    var.existing_ecs_cluster_name != null ?
    var.existing_ecs_cluster_name :
    aws_ecs_cluster.perforce_web_services_cluster[0].name
  )
  container_name   = var.p4_code_review_config.container_name
  container_port   = var.p4_code_review_config.container_port
  container_cpu    = var.p4_code_review_config.container_cpu
  container_memory = var.p4_code_review_config.container_memory
  p4d_port         = var.p4_code_review_config.p4d_port != null ? var.p4_code_review_config.p4d_port : local.p4_port
  p4charset = var.p4_code_review_config.p4charset != null ? var.p4_code_review_config.p4charset : (
    var.p4_server_config != null ? (
      var.p4_server_config.unicode ? "auto" : "none"
    ) : "none"
  )
  existing_redis_connection = var.p4_code_review_config.existing_redis_connection

  # Storage & Logging
  enable_alb_access_logs           = false
  cloudwatch_log_retention_in_days = var.p4_code_review_config.cloudwatch_log_retention_in_days

  # Networking & Security
  vpc_id  = var.vpc_id
  subnets = var.p4_code_review_config.service_subnets

  create_application_load_balancer = false
  internal                         = var.p4_code_review_config.internal

  create_default_role = var.p4_code_review_config.create_default_role
  custom_role         = var.p4_code_review_config.custom_role

  super_user_password_secret_arn          = module.p4_server[0].super_user_password_secret_arn
  super_user_username_secret_arn          = module.p4_server[0].super_user_username_secret_arn
  p4_code_review_user_password_secret_arn = module.p4_server[0].super_user_password_secret_arn
  p4_code_review_user_username_secret_arn = module.p4_server[0].super_user_username_secret_arn

  enable_sso        = var.p4_code_review_config.enable_sso
  config_php_source = var.p4_code_review_config.config_php_source

  depends_on = [aws_ecs_cluster.perforce_web_services_cluster[0]]
}

#################################################
# Shared ECS Cluster (Perforce Web Services)
#################################################
resource "aws_ecs_cluster" "perforce_web_services_cluster" {
  # Create shared ECS Cluster only if existing cluster is not passed into root module, and both p4_auth and p4_code_review variables are defined
  count = local.create_shared_ecs_cluster ? 1 : 0

  name = var.shared_ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags,
    {
      Name = var.shared_ecs_cluster_name
    }
  )
}

###################################################################
# Shared ECS Cluster (Perforce Web Services) | Capacity Providers
###################################################################
resource "aws_ecs_cluster_capacity_providers" "providers" {
  count        = local.create_shared_ecs_cluster ? 1 : 0
  cluster_name = aws_ecs_cluster.perforce_web_services_cluster[0].name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
