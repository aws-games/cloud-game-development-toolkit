data "aws_caller_identity" "current" {}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

data "aws_eks_cluster" "main" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = local.cluster_name
}