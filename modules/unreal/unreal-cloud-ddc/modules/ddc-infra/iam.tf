################################################################################
# EKS OIDC Provider for IRSA (Foundation)
################################################################################

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  count = var.is_primary_region ? 1 : 0
  
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-oidc-provider"
  })
}

################################################################################
# EKS Cluster IAM Role (Primary Infrastructure)
################################################################################
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name_prefix        = "${local.name_prefix}-cluster-"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-cluster-role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_compute_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_block_storage_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_load_balancing_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_networking_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

# Custom tagging policy for EKS Auto Mode - required for NodeClass with custom tags
data "aws_iam_policy_document" "eks_cluster_custom_tags" {
  statement {
    sid    = "Compute"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
      "ec2:CreateLaunchTemplate"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = ["$${aws:PrincipalTag/eks:eks-cluster-name}"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/eks:kubernetes-node-class-name"
      values   = ["*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/eks:kubernetes-node-pool-name"
      values   = ["*"]
    }
  }
}

resource "aws_iam_policy" "eks_cluster_custom_tags" {
  name_prefix = "${local.name_prefix}-cluster-custom-tags-"
  policy      = data.aws_iam_policy_document.eks_cluster_custom_tags.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_custom_tags" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = aws_iam_policy.eks_cluster_custom_tags.arn
}

################################################################################
# EKS Node IAM Role (Primary Infrastructure)
################################################################################
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com",
        "eks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "eks_node_role" {
  name_prefix        = "${local.name_prefix}-node-"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-node-role"
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_worker_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

################################################################################
# AWS Load Balancer Controller IAM Role (Infrastructure Service)
################################################################################
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  count = var.is_primary_region ? 1 : 0
  
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller_role" {
  count              = var.is_primary_region ? 1 : 0
  name_prefix        = "${local.name_prefix}-lbc-"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role[0].json
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-aws-load-balancer-controller-role"
  })
}

# AWS Load Balancer Controller requires specific permissions
data "aws_iam_policy_document" "aws_load_balancer_controller_policy" {
  count = var.is_primary_region ? 1 : 0
  
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "ec2:GetSecurityGroupsForVpc",
      "ec2:DescribeIpamPools",
      "ec2:DescribeRouteTables",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTrustStores",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeCapacityReservation"
    ]
    resources = ["*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup"
    ]
    resources = ["*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule"
    ]
    resources = ["*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["true"]
    }
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
      "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
    ]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyListenerAttributes",
      "elasticloadbalancing:ModifyCapacityReservation",
      "elasticloadbalancing:ModifyIpPools"
    ]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags"
    ]
    resources = [
      "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
      "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "elasticloadbalancing:CreateAction"
      values   = ["CreateTargetGroup", "CreateLoadBalancer"]
    }
    condition {
      test     = "Null"
      variable = "aws:RequestTag/elbv2.k8s.aws/cluster"
      values   = ["false"]
    }
  }
  
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
    resources = ["arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:SetRulePriorities"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-lbc-policy-"
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller_policy[0].json
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.aws_load_balancer_controller_role[0].name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy[0].arn
}

# Custom policy for AWS Load Balancer Controller security group management
data "aws_iam_policy_document" "aws_load_balancer_controller_security_groups" {
  count = var.is_primary_region ? 1 : 0
  
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller_security_groups" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-lbc-sg-"
  policy      = data.aws_iam_policy_document.aws_load_balancer_controller_security_groups[0].json
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_security_groups" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.aws_load_balancer_controller_role[0].name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_security_groups[0].arn
}

################################################################################
# External-DNS IAM Role (Infrastructure Service)
################################################################################
data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:external-dns:external-dns"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${local.name_prefix}-external-dns-role"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "external_dns_policy" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = var.route53_hosted_zone_name != null ? [data.aws_route53_zone.user_provided[0].arn] : ["arn:aws:route53:::hostedzone/*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "external_dns" {
  name   = "external-dns-policy"
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.external_dns_policy.json
}

################################################################################
# Cert Manager IAM Role (Infrastructure Service)
################################################################################
data "aws_iam_policy_document" "cert_manager_assume_role" {
  count = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
  
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:cert-manager:cert-manager"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cert_manager_role" {
  count              = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
  name_prefix        = "${local.name_prefix}-cert-"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume_role[0].json
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cert-manager-role"
  })
}

data "aws_iam_policy_document" "cert_manager_policy" {
  count = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
  
  statement {
    effect = "Allow"
    actions = [
      "route53:GetChange",
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZonesByName",
      "route53:ListHostedZones"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cert_manager_policy" {
  count       = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
  name_prefix = "${local.name_prefix}-cert-policy-"
  policy      = data.aws_iam_policy_document.cert_manager_policy[0].json
}

resource "aws_iam_role_policy_attachment" "cert_manager_policy_attachment" {
  count      = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
  role       = aws_iam_role.cert_manager_role[0].name
  policy_arn = aws_iam_policy.cert_manager_policy[0].arn
}

################################################################################
# FluentBit IAM Role (Infrastructure Service)
################################################################################
data "aws_iam_policy_document" "fluent_bit_assume_role" {
  count = var.is_primary_region ? 1 : 0
  
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc[0].arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-for-fluent-bit"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fluent_bit_role" {
  count              = var.is_primary_region ? 1 : 0
  name_prefix        = "${local.name_prefix}-fluentbit-"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume_role[0].json
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-fluent-bit-role"
  })
}

data "aws_iam_policy_document" "fluent_bit_policy" {
  count = var.is_primary_region ? 1 : 0
  
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:${var.region}:*:*"]
  }
}

resource "aws_iam_policy" "fluent_bit_policy" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-fluentbit-policy-"
  policy      = data.aws_iam_policy_document.fluent_bit_policy[0].json
}

resource "aws_iam_role_policy_attachment" "fluent_bit_policy_attachment" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.fluent_bit_role[0].name
  policy_arn = aws_iam_policy.fluent_bit_policy[0].arn
}

################################################################################
# DDC Application IAM (Application Level)
################################################################################

resource "aws_iam_policy" "s3_secrets_manager_iam_policy" {
  count       = var.is_primary_region ? 1 : 0
  name_prefix = "${local.name_prefix}-s3-policy-"
  path        = "/"
  description = "Policy to grant access to unreal cloud ddc bucket"

  policy = data.aws_iam_policy_document.unreal_cloud_ddc_policy.json
}

data "aws_iam_policy_document" "ddc_sa_assume_role" {
  count = var.is_primary_region ? 1 : 0
  
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc[0].arn]
    }
    
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.unreal_cloud_ddc_namespace}:${var.unreal_cloud_ddc_service_account_name}"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# DDC service account role - uses EKS OIDC Provider
resource "aws_iam_role" "unreal_cloud_ddc_sa_iam_role" {
  count              = var.is_primary_region ? 1 : 0
  name_prefix        = "${local.name_prefix}-sa-"
  assume_role_policy = data.aws_iam_policy_document.ddc_sa_assume_role[0].json
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-sa-role"
  })
}

resource "aws_iam_role_policy_attachment" "unreal_cloud_ddc_sa_iam_role_s3_secrets_policy_attachment" {
  count      = var.is_primary_region ? 1 : 0
  role       = aws_iam_role.unreal_cloud_ddc_sa_iam_role[0].name
  policy_arn = aws_iam_policy.s3_secrets_manager_iam_policy[0].arn
}

################################################################################
# ScyllaDB IAM (Optional Component)
################################################################################
data "aws_iam_policy_document" "scylla_assume_role" {
  count = var.scylla_config != null ? 1 : 0
  
  statement {
    sid    = "ScyllaDbRole"
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scylla_role" {
  count              = var.scylla_config != null ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.scylla_assume_role[0].json
  name_prefix        = "scylla-db-"
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-role"
  })
}

resource "aws_iam_role_policy_attachments_exclusive" "scylla_policy_attachement" {
  count = var.scylla_config != null ? 1 : 0
  
  role_name = aws_iam_role.scylla_role[0].name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_iam_instance_profile" "scylla_instance_profile" {
  count = var.scylla_config != null ? 1 : 0
  
  name = "${local.name_prefix}-scylladb-instance-profile-${var.region}"
  role = aws_iam_role.scylla_role[0].name
}

################################################################################
# CodeBuild IAM Role (Cluster Setup)
################################################################################
data "aws_iam_policy_document" "cluster_setup_codebuild_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster_setup_codebuild_role" {
  name_prefix        = "${local.name_prefix}-setup-"
  assume_role_policy = data.aws_iam_policy_document.cluster_setup_codebuild_assume_role.json
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cluster-setup-codebuild-role"
  })
}

data "aws_iam_policy_document" "cluster_setup_codebuild_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.region}:*:*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = ["${aws_s3_bucket.manifests.arn}/*"]
  }
  
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cluster_setup_codebuild_policy" {
  name   = "cluster-setup-policy"
  role   = aws_iam_role.cluster_setup_codebuild_role.id
  policy = data.aws_iam_policy_document.cluster_setup_codebuild_policy.json
}

################################################################################
# Policy Documents (Supporting Resources)
################################################################################
data "aws_iam_policy_document" "unreal_cloud_ddc_policy" {
  # S3 for Service Account
  statement {
    sid    = "S3Allow"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
      "s3:DeleteObjectTagging",
      "s3:DeleteObject",
      "s3:List*",
    ]
    resources = [
      aws_s3_bucket.unreal_ddc_s3_bucket.arn,
      "${aws_s3_bucket.unreal_ddc_s3_bucket.arn}/*"
    ]
  }
  
  # Secrets Manager for Service account
  dynamic "statement" {
    for_each = compact([var.oidc_credentials_secret_manager_arn])
    content {
      sid    = "SecretsManagerGet"
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue"
      ]
      resources = [
        statement.value,
      ]
    }
  }
}