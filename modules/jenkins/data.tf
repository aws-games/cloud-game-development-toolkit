data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# If cluster name is provided use a data source to access existing resource
data "aws_ecs_cluster" "jenkins_cluster" {
  count        = var.cluster_name != null ? 1 : 0
  cluster_name = var.cluster_name
}

# Get target VPC
data "aws_vpc" "build_farm_vpc" {
  id = var.vpc_id
}

data "aws_route_table" "build_farm_route_table" {
  count     = length(var.build_farm_subnets)
  subnet_id = var.build_farm_subnets[count.index]
}
