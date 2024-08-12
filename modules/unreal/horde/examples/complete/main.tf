data "aws_availability_zones" "available" {}

locals {
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  azs                  = slice(data.aws_availability_zones.available.names, 0, 2)
  tags                 = {}
}

# Create ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "horde-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Specify Fargate Capacity Provider for Cluster
resource "aws_ecs_cluster_capacity_providers" "providers" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

module "unreal_horde" {
  source                        = "../../"
  unreal_horde_subnets          = aws_subnet.private_subnets[*].id
  unreal_horde_alb_subnets      = aws_subnet.public_subnets[*].id
  vpc_id                        = aws_vpc.unreal_horde_vpc.id
  cluster_name                  = aws_ecs_cluster.cluster.name
  certificate_arn               = aws_acm_certificate.unreal_horde.arn
  github_credentials_secret_arn = var.github_credentials_secret_arn
  tags                          = local.tags

  depends_on = [aws_ecs_cluster.cluster]
}
