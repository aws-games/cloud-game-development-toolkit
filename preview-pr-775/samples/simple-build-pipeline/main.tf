##########################################
# Shared ECS Cluster for Services
##########################################

resource "aws_ecs_cluster" "build_pipeline_cluster" {
  name = "build-pipeline-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "providers" {
  cluster_name = aws_ecs_cluster.build_pipeline_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

##########################################
# Perforce
##########################################

module "terraform-aws-perforce" {
  source = "../../modules/perforce"

  # - Shared -
  project_prefix = "cgd"
  vpc_id         = aws_vpc.build_pipeline_vpc.id

  create_route53_private_hosted_zone      = false # shared private hosted zone with Jenkins
  create_shared_application_load_balancer = false # shared ALB with Jenkins
  create_shared_network_load_balancer     = false # shared NLB with Jenkins
  existing_ecs_cluster_name               = aws_ecs_cluster.build_pipeline_cluster.name

  # - P4 Server Configuration -
  p4_server_config = {
    # General
    name                        = "p4-server"
    fully_qualified_domain_name = "perforce.${var.route53_public_hosted_zone_name}"

    # Compute
    p4_server_type = "p4d_commit"

    # Storage
    depot_volume_size    = 128
    metadata_volume_size = 32
    logs_volume_size     = 32

    # Networking & Security
    instance_subnet_id       = aws_subnet.public_subnets[0].id
    existing_security_groups = [aws_security_group.allow_my_ip.id] # grants end user access

    auth_service_url = "https://${local.p4_auth_fully_qualified_domain_name}"
  }

  # - P4Auth Configuration -
  p4_auth_config = {
    # General
    name                        = "p4-auth"
    fully_qualified_domain_name = local.p4_auth_fully_qualified_domain_name
    debug                       = true # optional to use for debugging. Default is false if omitted
    deregistration_delay        = 0
    service_subnets             = aws_subnet.private_subnets[*].id
    # Allow ECS tasks to be immediately deregistered from target group. Helps to prevent race conditions during `terraform destroy`
  }


  # - P4 Code Review Configuration -
  p4_code_review_config = {
    name                        = "p4-code-review"
    fully_qualified_domain_name = local.p4_code_review_fully_qualified_domain_name
    debug                       = true # optional to use for debugging. Default is false if omitted
    deregistration_delay        = 0
    service_subnets             = aws_subnet.private_subnets[*].id
    # Allow ECS tasks to be immediately deregistered from target group. Helps to prevent race conditions during `terraform destroy`

    # Configuration
    enable_sso = true

    p4d_port = "ssl:${local.p4_server_fully_qualified_domain_name}:1666"
  }
}
##########################################
# Jenkins
##########################################

module "jenkins" {
  source = "../../modules/jenkins"

  cluster_name                     = aws_ecs_cluster.build_pipeline_cluster.name
  vpc_id                           = aws_vpc.build_pipeline_vpc.id
  jenkins_alb_subnets              = aws_subnet.public_subnets[*].id
  jenkins_service_subnets          = aws_subnet.private_subnets[*].id
  jenkins_agent_secret_arns        = local.jenkins_agent_secret_arns
  create_ec2_fleet_plugin_policy   = true
  create_application_load_balancer = false

  # Build Farms
  build_farm_subnets = aws_subnet.private_subnets[*].id

  build_farm_compute = local.build_farm_compute

  build_farm_fsx_openzfs_storage = local.build_farm_fsx_openzfs_storage

  # Artifacts
  artifact_buckets = {
    builds : {
      name                 = "game-builds"
      enable_force_destroy = true

      tags = {
        Name = "game-builds"
      }
    },
  }

  depends_on = [aws_ecs_cluster.build_pipeline_cluster, aws_acm_certificate_validation.shared_certificate]
}

# placeholder since provider is "required" by the module
provider "netapp-ontap" {
  connection_profiles = [
    {
      name     = "null"
      hostname = "null"
      username = "null"
      password = "null"
    }
  ]
}
