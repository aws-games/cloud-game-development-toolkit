# Data sources for provider configuration
data "aws_eks_cluster" "main" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = local.cluster_name
}

# Get current IP for security groups
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}