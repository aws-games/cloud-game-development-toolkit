# tflint-ignore: terraform_required_version

##########################################
# Shared ECS Cluster for Services
##########################################

resource "aws_ecs_cluster" "jenkins_cluster" {
  name = "jenkins-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "providers" {
  cluster_name = aws_ecs_cluster.jenkins_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

##########################################
# Jenkins
##########################################

module "jenkins" {
  source = "../.."

  cluster_name                           = aws_ecs_cluster.jenkins_cluster.name
  vpc_id                                 = aws_vpc.jenkins_vpc.id
  jenkins_alb_subnets                    = aws_subnet.public_subnets[*].id
  jenkins_service_subnets                = aws_subnet.private_subnets[*].id
  existing_security_groups               = []
  internal                               = false
  certificate_arn                        = aws_acm_certificate.jenkins.arn
  jenkins_agent_secret_arns              = var.jenkins_agent_secret_arns
  create_ec2_fleet_plugin_policy         = true
  debug                                  = true
  enable_jenkins_alb_deletion_protection = false
  enable_default_efs_backup_plan         = false

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

  depends_on = [aws_ecs_cluster.jenkins_cluster, aws_acm_certificate_validation.jenkins]
}
