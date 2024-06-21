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
# Perforce Helix Core
##########################################

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

  FQDN = "core.helix.perforce.${var.fully_qualified_domain_name}"

  helix_authentication_service_url = "https://${aws_route53_record.helix_authentication_service.name}"
}

resource "aws_vpc_security_group_ingress_rule" "helix_auth_inbound_core" {
  security_group_id = module.perforce_helix_authentication_service.alb_security_group_id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "${module.perforce_helix_core.helix_core_eip_public_ip}/32"
  description       = "Enables Helix Core to access Helix Authentication Service"
}

resource "aws_vpc_security_group_ingress_rule" "helix_swarm_inbound_core" {
  security_group_id = module.perforce_helix_swarm.alb_security_group_id
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "${module.perforce_helix_core.helix_core_eip_public_ip}/32"
  description       = "Enables Helix Core to access Helix Swarm"
}

##########################################
# Perforce Helix Authentication Service
##########################################

module "perforce_helix_authentication_service" {
  source                                   = "../../modules/perforce/helix-authentication-service"
  vpc_id                                   = aws_vpc.build_pipeline_vpc.id
  cluster_name                             = aws_ecs_cluster.build_pipeline_cluster.name
  helix_authentication_service_alb_subnets = aws_subnet.public_subnets[*].id
  helix_authentication_service_subnets     = aws_subnet.private_subnets[*].id
  certificate_arn                          = aws_acm_certificate.helix.arn

  enable_web_based_administration = true
  fqdn                            = "https://auth.helix.${var.fully_qualified_domain_name}"

  depends_on = [aws_ecs_cluster.build_pipeline_cluster, aws_acm_certificate_validation.helix]
}

##########################################
# Perforce Helix Swarm
##########################################

module "perforce_helix_swarm" {
  source                      = "../../modules/perforce/helix-swarm"
  vpc_id                      = aws_vpc.build_pipeline_vpc.id
  cluster_name                = aws_ecs_cluster.build_pipeline_cluster.name
  swarm_alb_subnets           = aws_subnet.public_subnets[*].id
  swarm_service_subnets       = aws_subnet.private_subnets[*].id
  certificate_arn             = aws_acm_certificate.helix.arn
  p4d_port                    = "ssl:${aws_route53_record.perforce_helix_core_pvt.name}:1666"
  enable_elastic_filesystem   = false
  p4d_super_user_arn          = module.perforce_helix_core.helix_core_super_user_username_secret_arn
  p4d_super_user_password_arn = module.perforce_helix_core.helix_core_super_user_password_secret_arn
  p4d_swarm_user_arn          = module.perforce_helix_core.helix_core_super_user_username_secret_arn
  p4d_swarm_password_arn      = module.perforce_helix_core.helix_core_super_user_password_secret_arn

  fqdn = "swarm.helix.${var.fully_qualified_domain_name}"

  depends_on = [aws_ecs_cluster.build_pipeline_cluster, aws_acm_certificate_validation.helix]
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inbound_swarm" {
  security_group_id            = module.perforce_helix_core.security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.perforce_helix_swarm.service_security_group_id
  description                  = "Enables Helix Swarm to access Helix Core."
}

##########################################
# Jenkins
##########################################


module "jenkins" {
  source = "../../modules/jenkins"

  cluster_name              = aws_ecs_cluster.build_pipeline_cluster.name
  vpc_id                    = aws_vpc.build_pipeline_vpc.id
  jenkins_alb_subnets       = aws_subnet.public_subnets[*].id
  jenkins_service_subnets   = aws_subnet.private_subnets[*].id
  existing_security_groups  = []
  internal                  = false
  certificate_arn           = aws_acm_certificate.jenkins.arn
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

  depends_on = [aws_ecs_cluster.build_pipeline_cluster, aws_acm_certificate_validation.jenkins]
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inbound_build_farm" {
  security_group_id            = module.perforce_helix_core.security_group_id
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.jenkins.build_farm_security_group
  description                  = "Enables build farm to access Helix Core."
}
