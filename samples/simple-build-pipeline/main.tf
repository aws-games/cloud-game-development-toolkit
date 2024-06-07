######################
# Perforce
######################

resource "aws_ecs_cluster" "p4_cluster" {
  name = "p4-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "providers" {
  cluster_name = aws_ecs_cluster.p4_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

module "perforce_helix_core" {
  source             = "../../modules/perforce/helix-core"
  vpc_id             = aws_vpc.build_pipeline_vpc.id
  server_type        = "p4d_master"
  instance_subnet_id = aws_subnet.public_subnets[0].id
  instance_type      = "c6in.large"

  storage_type         = "EBS"
  depot_volume_size    = 64
  metadata_volume_size = 32
  logs_volume_size     = 32
}

module "perforce_helix_authentication_service" {
  source              = "../../modules/perforce/helix-authentication-service"
  vpc_id              = aws_vpc.build_pipeline_vpc.id
  cluster_name        = aws_ecs_cluster.p4_cluster.name
  HAS_alb_subnets     = aws_subnet.public_subnets[*].id
  HAS_service_subnets = aws_subnet.private_subnets[*].id
  certificate_arn     = var.helix_authentication_service_certificate_arn

  enable_web_based_administration = false

  depends_on = [aws_ecs_cluster.p4_cluster]
}


module "perforce_helix_swarm" {
  source                      = "../../modules/perforce/helix-swarm"
  vpc_id                      = aws_vpc.build_pipeline_vpc.id
  cluster_name                = aws_ecs_cluster.p4_cluster.name
  swarm_alb_subnets           = aws_subnet.public_subnets[*].id
  swarm_service_subnets       = aws_subnet.private_subnets[*].id
  certificate_arn             = var.helix_swarm_certificate_arn
  p4d_port                    = "ssl:${aws_route53_record.perforce_helix_core.name}:1666"
  enable_elastic_filesystem   = false
  p4d_super_user_arn          = var.helix_swarm_environment_variables.p4d_super_user_arn
  p4d_super_user_password_arn = var.helix_swarm_environment_variables.p4d_super_user_password_arn
  p4d_swarm_user_arn          = var.helix_swarm_environment_variables.p4d_swarm_user_arn
  p4d_swarm_password_arn      = var.helix_swarm_environment_variables.p4d_swarm_password_arn

  depends_on = [aws_ecs_cluster.p4_cluster]
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inbound_swarm" {
  security_group_id            = module.perforce_helix_core.security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.perforce_helix_swarm.service_security_group_id
  description                  = "Enables Helix Swarm to access Helix Core."
}

######################
# Jenkins
######################

module "jenkins" {
  source = "../../modules/jenkins"

  vpc_id                    = aws_vpc.build_pipeline_vpc.id
  jenkins_alb_subnets       = aws_subnet.public_subnets[*].id
  jenkins_service_subnets   = aws_subnet.private_subnets[*].id
  existing_security_groups  = []
  internal                  = false
  certificate_arn           = var.jenkins_certificate_arn
  jenkins_agent_secret_arns = var.jenkins_agent_secret_arns

  # Build Farms
  build_farm_subnets = aws_subnet.private_subnets[*].id

  build_farm_compute = var.build_farm_compute

  build_farm_fsx_openzfs_storage = var.build_farm_fsx_openzfs_storage
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
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inbound_build_farm" {
  security_group_id            = module.perforce_helix_core.security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.jenkins.build_farm_security_group
  description                  = "Enables build farm to access Helix Core."
}
