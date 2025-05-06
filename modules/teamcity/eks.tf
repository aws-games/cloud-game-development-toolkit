###################################
# # EKS Cluster for Build Agents  #
###################################

resource "aws_security_group" "teamcity_eks_sg" {
  name        = "teamcity-eks-sg"
  description = "Security group for TeamCity EKS cluster"
  vpc_id      = var.vpc_id

}

resource "aws_vpc_security_group_ingress_rule" "eks_inbound_teamcity_service" {

  security_group_id = aws_security_group.teamcity_eks_sg.id
  description       = "Allow traffic from TeamCity service to EKS cluster"

  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_eks_cluster" "teamcity_eks_cluster" {
  #checkov:skip=CKV_AWS_58:EKS Cluster doesn't need Secrets Encryption Enabled right now
  #checkov:skip=CKV_AWS_37:Amazon EKS control plane logging not needed yet

  name = "example"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.eks_cluster.arn

  # i dont get this one it's on the newest version
  #checkov:skip=CKV_AWS_339:Ensure EKS clusters run on a supported Kubernetes version
  version = "1.32"

  bootstrap_self_managed_addons = false

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.teamcity_eks_sg.id]
    subnet_ids              = var.service_subnets
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSComputePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSBlockStoragePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSLoadBalancingPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSNetworkingPolicy,
  ]
}

resource "aws_iam_role" "node" {
  name = "eks-auto-node-example"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodeMinimalPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryPullOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role" "eks_cluster" {
  name = "teamcity-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

# create IAM user to establish a Kubernetes Connection with TeamCity
resource "aws_iam_user" "eks_user" {
  #checkov:skip=CKV_AWS_273:need IAM user for TeamCity
  name = "teamcity-eks-user"
}

# create an IAM access key for the IAM user "eks_user"
resource "aws_iam_access_key" "eks_iam_access_key" {
  user = aws_iam_user.eks_user.name
}

# Output secret... work in progress
output "secret" {
  value     = aws_iam_access_key.eks_iam_access_key.secret
  sensitive = true
}

# Allow admin to have access entry into the EKS to manage pods. Needed to create connection with TeamCity
resource "aws_eks_access_entry" "teamcity_eks_access_entry" {
  cluster_name  = aws_eks_cluster.teamcity_eks_cluster.name
  principal_arn = aws_iam_user.eks_user.arn
  type          = "STANDARD"
}

# Specific policy associations needed for access entry
resource "aws_eks_access_policy_association" "example" {
  cluster_name  = aws_eks_cluster.teamcity_eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_user.eks_user.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSComputePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSBlockStoragePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSLoadBalancingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSNetworkingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.eks_cluster.name
}
