##########################################
# Shared ECS Cluster for Services
##########################################

resource "aws_ecs_cluster" "unity_pipeline_cluster" {
  name = "${local.project_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "providers" {
  cluster_name = aws_ecs_cluster.unity_pipeline_cluster.name

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

module "perforce" {
  source = "../../modules/perforce"

  # - Shared -
  project_prefix = local.project_prefix
  vpc_id         = aws_vpc.unity_pipeline_vpc.id

  create_route53_private_hosted_zone      = true
  route53_private_hosted_zone_name        = local.perforce_fqdn
  create_shared_application_load_balancer = true
  shared_alb_subnets                      = aws_subnet.public_subnets[*].id
  create_shared_network_load_balancer     = true
  shared_nlb_subnets                      = aws_subnet.public_subnets[*].id
  existing_ecs_cluster_name               = aws_ecs_cluster.unity_pipeline_cluster.name
  certificate_arn                         = aws_acm_certificate.shared.arn

  # - P4 Server Configuration -
  p4_server_config = {
    # General
    name                        = "p4-server"
    fully_qualified_domain_name = local.perforce_fqdn

    # Compute
    p4_server_type = "p4d_commit"

    # Storage
    depot_volume_size    = 128
    metadata_volume_size = 32
    logs_volume_size     = 32

    # Networking & Security
    instance_subnet_id       = aws_subnet.public_subnets[0].id
    existing_security_groups = [aws_security_group.allow_my_ip.id]

    auth_service_url = "https://${local.p4_auth_fqdn}"
  }

  # - P4Auth Configuration -
  p4_auth_config = {
    # General
    name                        = "p4-auth"
    fully_qualified_domain_name = local.p4_auth_fqdn
    service_subnets             = aws_subnet.private_subnets[*].id
  }

  depends_on = [aws_acm_certificate_validation.shared]

  tags = local.tags
}

##########################################
# TeamCity
##########################################

module "teamcity" {
  source = "../../modules/teamcity"

  vpc_id              = aws_vpc.unity_pipeline_vpc.id
  service_subnets     = aws_subnet.private_subnets[*].id
  alb_subnets         = aws_subnet.public_subnets[*].id
  alb_certificate_arn = aws_acm_certificate.shared.arn

  cluster_name = aws_ecs_cluster.unity_pipeline_cluster.name
  environment  = "dev"

  build_farm_config = {
    "unity-builder" = {
      image         = "jetbrains/teamcity-agent"
      cpu           = 2048
      memory        = 4096
      desired_count = 2
    }
  }

  depends_on = [aws_acm_certificate_validation.shared]

  tags = local.tags
}

##########################################
# Unity Accelerator
##########################################

module "unity_accelerator" {
  source = "../../modules/unity/accelerator"

  vpc_id          = aws_vpc.unity_pipeline_vpc.id
  service_subnets = aws_subnet.private_subnets[*].id
  lb_subnets      = aws_subnet.public_subnets[*].id

  cluster_name        = aws_ecs_cluster.unity_pipeline_cluster.name
  alb_certificate_arn = aws_acm_certificate.shared.arn
  environment         = "dev"

  depends_on = [aws_acm_certificate_validation.shared]

  tags = local.tags
}
