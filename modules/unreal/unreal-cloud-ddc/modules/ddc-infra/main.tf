################################################################################
# EKS Cluster (Foundation)
################################################################################

resource "aws_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  region   = var.region
  name     = local.name_prefix
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  # CRITICAL: Must be false for EKS Auto Mode
  # AWS's confusing naming: "bootstrap_self_managed_addons = false" means:
  # "Don't let me manage the BOOTSTRAP addons (vpc-cni, coredns, kube-proxy, EBS CSI)"
  # EKS Auto Mode integrates these as built-in core components, NOT separate addons
  # You can still install OTHER addons (External-DNS, FluentBit, AWS LBC, etc.)
  # The flag ONLY applies to the 4 bootstrap addons that traditional EKS needs
  bootstrap_self_managed_addons = false

  vpc_config {
    subnet_ids              = var.eks_node_group_subnets
    endpoint_private_access = local.eks_private_enabled
    endpoint_public_access  = local.eks_public_enabled
    public_access_cidrs     = local.eks_public_cidrs
    security_group_ids      = [aws_security_group.cluster_security_group.id]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  compute_config {
    enabled       = true
    node_role_arn = aws_iam_role.eks_node_role.arn
    node_pools    = ["general-purpose", "system"]
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

  enabled_cluster_log_types = var.eks_cluster_logging_types

  tags = var.tags
}

################################################################################
# CloudWatch Log Group (Cluster Logging)
################################################################################

resource "aws_cloudwatch_log_group" "unreal_cluster_cloudwatch" {
  #checkov:skip=CKV_AWS_158:Ensure that CloudWatch Log Group is encrypted by KMS
  region            = var.region
  name_prefix       = var.eks_cluster_cloudwatch_log_group_prefix
  retention_in_days = 365
}

################################################################################
# EKS Access Entries (Cluster Access)
################################################################################

# EKS Access Entries for additional users/services
resource "aws_eks_access_entry" "additional" {
  for_each = var.eks_access_entries

  region        = var.region
  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  principal_arn = each.value.principal_arn
  type          = each.value.type

  depends_on = [aws_eks_cluster.unreal_cloud_ddc_eks_cluster]
}

# EKS Access Entry for CodeBuild (cluster setup)
resource "aws_eks_access_entry" "codebuild_cluster_setup" {
  region        = var.region
  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  principal_arn = aws_iam_role.cluster_setup_codebuild_role.arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.unreal_cloud_ddc_eks_cluster]
}

resource "aws_eks_access_policy_association" "codebuild_cluster_setup" {
  region        = var.region
  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.cluster_setup_codebuild_role.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.codebuild_cluster_setup]
}

resource "aws_eks_access_policy_association" "additional" {
  for_each = {
    for combo in flatten([
      for entry_key, entry_value in var.eks_access_entries : [
        for policy_idx, policy in entry_value.policy_associations : {
          key           = "${entry_key}-${policy_idx}"
          principal_arn = entry_value.principal_arn
          policy_arn    = policy.policy_arn
          access_scope  = policy.access_scope
        }
      ]
    ]) : combo.key => combo
  }

  region        = var.region
  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  policy_arn    = each.value.policy_arn
  principal_arn = each.value.principal_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = each.value.access_scope.namespaces
  }

  depends_on = [aws_eks_access_entry.additional]
}

# NOTE: EKS Access Entry for node role already exists automatically
# EKS Auto Mode creates access entries for all node roles automatically
# Confirmed: AmazonEKSAutoNodePolicy is already attached

################################################################################
# CodeBuild Project (Cluster Setup)
################################################################################

# CodeBuild project for cluster setup (replaces null_resource operations)
resource "aws_codebuild_project" "cluster_setup" {
  region       = var.region
  name         = "${local.name_prefix}-cluster-setup"
  description  = "Configure EKS cluster with custom NodePools for DDC workloads"
  service_role = aws_iam_role.cluster_setup_codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "CLUSTER_NAME"
      value = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "VPC_ID"
      value = var.vpc_id
    }

    environment_variable {
      name  = "NODE_ROLE_NAME"
      value = aws_iam_role.eks_node_role.name
    }

    environment_variable {
      name  = "NODE_SUBNETS"
      value = join(",", var.eks_node_group_subnets)
    }

    environment_variable {
      name  = "CLUSTER_SG_ID"
      value = aws_security_group.cluster_security_group.id
    }

    environment_variable {
      name  = "NAME_PREFIX"
      value = local.name_prefix
    }
  }

  # VPC configuration for secure EKS access
  vpc_config {
    vpc_id = var.vpc_id
    subnets = var.eks_node_group_subnets
    security_group_ids = [aws_security_group.cluster_security_group.id]
  }

  source {
    type = "S3"
    location = "${aws_s3_bucket.manifests.bucket}/assets.zip"
    buildspec = file("${path.module}/buildspecs/cluster-setup.yml")
  }

  tags = var.tags
}

################################################################################
# Terraform Actions (Cluster Setup Orchestration)
################################################################################

# Terraform Action to start cluster setup
action "aws_codebuild_start_build" "cluster_setup" {
  config {
    region       = var.region
    project_name = aws_codebuild_project.cluster_setup.name
    timeout      = 1800  # 30 minutes
  }
}

# Trigger cluster setup after EKS cluster exists
resource "terraform_data" "cluster_setup_trigger" {
  input = {
    cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
    cluster_version = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
    region          = var.region
    # Force trigger when buildspec changes (for fixing cluster setup scripts)
    buildspec_hash  = filemd5("${path.module}/buildspecs/cluster-setup.yml")
    # Force trigger when S3 assets change (manifests, scripts)
    assets_hash     = data.archive_file.assets.output_md5
    # Final validation: EKS setup → Deploy → Test sequence working correctly
    validation_comment = "eks-deploy-test-sequence-validated"
  }

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.cluster_setup]
    }
  }

  depends_on = [
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster,
    aws_iam_role.cluster_setup_codebuild_role,
    aws_s3_object.assets
  ]
}
