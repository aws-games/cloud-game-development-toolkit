data "aws_region" "current" {}

# Fetch AWS caller identity (i.e. the AWS user or role that Terraform is authenticated as)
data "aws_caller_identity" "current" {
}

# If cluster name is provided use a data source to access existing resource
data "aws_ecs_cluster" "helix_swarm_cluster" {
  count        = var.cluster_name != null ? 1 : 0
  cluster_name = var.cluster_name
}
