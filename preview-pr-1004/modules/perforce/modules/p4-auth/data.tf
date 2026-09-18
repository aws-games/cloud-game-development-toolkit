data "aws_region" "current" {}

# If cluster name is provided use a data source to access existing resource
data "aws_ecs_cluster" "cluster" {
  count        = var.cluster_name != null ? 1 : 0
  cluster_name = var.cluster_name
}
