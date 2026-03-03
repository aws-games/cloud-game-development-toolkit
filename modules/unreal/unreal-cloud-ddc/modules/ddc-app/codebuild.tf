################################################################################
# CodeBuild Project for DDC Deployment
################################################################################

resource "aws_codebuild_project" "ddc_deployer" {
  name         = "${local.name_prefix}-ddc-deployer"
  description  = "Deploy Unreal Cloud DDC via Helm to EKS cluster"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "CLUSTER_NAME"
      value = var.cluster_name
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "NAMESPACE"
      value = var.namespace
    }

    environment_variable {
      name  = "NAME_PREFIX"
      value = local.name_prefix
    }

    environment_variable {
      name  = "GHCR_SECRET_ARN"
      value = var.ghcr_credentials_secret_arn
    }

    environment_variable {
      name  = "DDC_CHART"
      value = var.ddc_application_config.helm_chart
    }

    environment_variable {
      name  = "DEBUG"
      value = var.debug ? "true" : "false"
    }

    environment_variable {
      name  = "HELM_VALUES_CONTENT"
      value = base64encode(local_file.ddc_helm_values.content)
    }

    # ScyllaDB Keyspace Configuration
    environment_variable {
      name  = "SCYLLA_KEYSPACE_ENABLED"
      value = var.database_connection.type == "scylla" && var.ssm_document_name != null ? "true" : "false"
    }

    environment_variable {
      name  = "SSM_DOCUMENT_NAME"
      value = var.ssm_document_name != null ? var.ssm_document_name : ""
    }

    environment_variable {
      name  = "SCYLLA_SEED_INSTANCE_ID"
      value = var.scylla_seed_instance_id != null ? var.scylla_seed_instance_id : ""
    }

    # Functional Testing Configuration
    environment_variable {
      name  = "ENABLE_FUNCTIONAL_TESTING"
      value = var.ddc_application_config.enable_single_region_validation || var.ddc_application_config.enable_multi_region_validation ? "true" : "false"
    }

    environment_variable {
      name  = "PEER_REGION_DDC_ENDPOINT"
      value = var.ddc_application_config.peer_region_ddc_endpoint != null ? var.ddc_application_config.peer_region_ddc_endpoint : ""
    }
  }

  # TEMPORARILY REMOVED: VPC configuration causing similar issues as ddc-infra
  # vpc_config {
  #   vpc_id = var.vpc_id
  #   subnets = var.subnets
  #   security_group_ids = var.security_group_ids
  # }

  source {
    type = "S3"
    location = "${aws_s3_bucket.assets.bucket}/assets.zip"
    buildspec = file("${path.module}/buildspecs/deploy-ddc.yml")
  }

  tags = var.tags
}

################################################################################
# Terraform Actions for DDC Deployment
################################################################################

resource "terraform_data" "deploy_trigger" {
  input = {
    cluster_name = var.cluster_name
    ddc_version  = var.ddc_application_config.helm_chart
    config_hash  = sha256(jsonencode(var.ddc_application_config))
    values_hash  = local_file.ddc_helm_values.content_md5
    # Force trigger when buildspec changes (for fixing deployment scripts)
    buildspec_hash = filemd5("${path.module}/buildspecs/deploy-ddc.yml")
    # Force trigger when S3 assets change
    assets_hash    = data.archive_file.assets.output_md5
  }

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.deploy_ddc]
    }
  }
}

action "aws_codebuild_start_build" "deploy_ddc" {
  config {
    project_name = aws_codebuild_project.ddc_deployer.name
  }
}

################################################################################
# EKS Access Entry for CodeBuild
################################################################################

# EKS Access Entry for CodeBuild (app deployment)
resource "aws_eks_access_entry" "codebuild_app_deployment" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.codebuild_role.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "codebuild_app_deployment" {
  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.codebuild_role.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.codebuild_app_deployment,
    aws_s3_object.assets
  ]
}

################################################################################
# IAM Role for CodeBuild
################################################################################

data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild_policy" {
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
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",
      "eks:DescribeUpdate",
      "eks:ListUpdates"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [var.ghcr_credentials_secret_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = ["${aws_s3_bucket.assets.arn}/*"]
  }

  # Additional permissions for Kubernetes API access
  statement {
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }

  # SSM permissions for ScyllaDB keyspace configuration
  statement {
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:DescribeInstanceInformation"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "codebuild_role" {
  name               = "${local.name_prefix}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "${local.name_prefix}-codebuild-policy"
  role   = aws_iam_role.codebuild_role.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}
