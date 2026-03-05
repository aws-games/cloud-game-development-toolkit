################################################################################
# CodeBuild Project for DDC Deployment (Deploy Only)
################################################################################

resource "aws_codebuild_project" "ddc_deployer" {
  name         = "${local.name_prefix}-ddc-deployer"
  description  = "Deploy Unreal Cloud DDC via Helm to EKS cluster"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # VPC configuration for secure EKS access
  vpc_config {
    vpc_id = var.vpc_id
    subnets = var.eks_node_group_subnets
    security_group_ids = [var.cluster_security_group_id]
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
  }

  source {
    type = "S3"
    location = "${aws_s3_bucket.assets.bucket}/assets.zip"
    buildspec = file("${path.module}/buildspecs/deploy-ddc.yml")
  }

  tags = var.tags
}

################################################################################
# CodeBuild Project for DDC Testing (Test Only)
################################################################################

resource "aws_codebuild_project" "ddc_tester" {
  name         = "${local.name_prefix}-ddc-tester"
  description  = "Test Unreal Cloud DDC functionality after deployment"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # VPC configuration for secure EKS access
  vpc_config {
    vpc_id = var.vpc_id
    subnets = var.eks_node_group_subnets
    security_group_ids = [var.cluster_security_group_id]
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

    # DNS endpoint for comprehensive testing
    environment_variable {
      name  = "DDC_DNS_ENDPOINT"
      value = var.ddc_dns_endpoint != null ? var.ddc_dns_endpoint : ""
    }

    # Bearer token secret ARN for API authentication testing
    environment_variable {
      name  = "BEARER_TOKEN_SECRET_ARN"
      value = var.bearer_token_secret_arn != null ? var.bearer_token_secret_arn : ""
    }

    environment_variable {
      name  = "DEFAULT_DDC_NAMESPACE"
      value = var.ddc_application_config.default_ddc_namespace
    }

    environment_variable {
      name  = "PEER_REGION_DDC_ENDPOINT"
      value = var.ddc_application_config.peer_region_ddc_endpoint != null ? var.ddc_application_config.peer_region_ddc_endpoint : ""
    }

    # Test configuration
    environment_variable {
      name  = "MAX_TEST_ATTEMPTS"
      value = "30"
    }

    environment_variable {
      name  = "DEBUG"
      value = var.debug ? "true" : "false"
    }
  }

  source {
    type = "S3"
    location = "${aws_s3_bucket.assets.bucket}/assets.zip"
    buildspec = file("${path.module}/buildspecs/test-ddc.yml")
  }

  tags = var.tags
}

################################################################################
# Terraform Actions for DDC Deployment
#
# WORKAROUND: Due to a Terraform Actions bug, depends_on is ignored between
# action-triggered resources, causing parallel execution instead of sequential.
#
# GitHub Issue: https://github.com/hashicorp/terraform/issues/38230
#
# Current Solution:
# - Deploy and test actions run in parallel (Terraform bug)
# - Test buildspec includes workaround script that waits for deploy completion
# - Script uses AWS CLI to monitor deploy CodeBuild status before proceeding
#
# Future Solutions (when bug is fixed):
# - Remove workaround script from test buildspec
# - Rely on native Terraform depends_on functionality
# - Alternative: Migrate to CodePipeline or Step Functions for orchestration
################################################################################

# Deploy action
# NOTE: This action runs in parallel with test action due to Terraform Actions bug
# The test action includes a workaround script to wait for this deploy to complete
resource "terraform_data" "deploy_trigger" {
  input = merge(
    {
      cluster_name = var.cluster_name
      ddc_version  = var.ddc_application_config.helm_chart
      config_hash  = sha256(jsonencode(var.ddc_application_config))
      values_hash  = local_file.ddc_helm_values.content_md5
      buildspec_hash = filemd5("${path.module}/buildspecs/deploy-ddc.yml")
      assets_hash    = data.archive_file.assets.output_md5
    },
    var.debug ? { debug_timestamp = timestamp() } : {}
  )

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.deploy_ddc]
    }
  }

  depends_on = [
    aws_s3_object.assets
  ]
}

# Test action - includes workaround for Terraform Actions dependency bug
# WORKAROUND: depends_on is ignored between action resources, so test runs in parallel
# with deploy. The test buildspec includes a script that waits for deploy completion.
resource "terraform_data" "test_trigger" {
  count = var.ddc_application_config.enable_single_region_validation || var.ddc_application_config.enable_multi_region_validation ? 1 : 0

  input = merge(
    {
      test_config_hash = sha256(jsonencode({
        dns_endpoint = var.ddc_dns_endpoint
        bearer_token_secret = var.bearer_token_secret_arn
        peer_endpoint = var.ddc_application_config.peer_region_ddc_endpoint
      }))
      test_buildspec_hash = filemd5("${path.module}/buildspecs/test-ddc.yml")
      assets_hash = data.archive_file.assets.output_md5
    },
    var.debug ? { debug_timestamp = timestamp() } : {}
  )

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.test_ddc]
    }
  }

  depends_on = [terraform_data.deploy_trigger]  # NOTE: This is ignored due to Terraform Actions bug
}

action "aws_codebuild_start_build" "deploy_ddc" {
  config {
    project_name = aws_codebuild_project.ddc_deployer.name
    timeout      = 1800  # 30 minutes
  }
}

action "aws_codebuild_start_build" "test_ddc" {
  config {
    project_name = aws_codebuild_project.ddc_tester.name
    timeout      = 3600  # 60 minutes (testing takes longer)
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
      "codebuild:ListBuildsForProject",
      "codebuild:BatchGetBuilds"
    ]
    resources = ["*"]
  }

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
    resources = [
      var.ghcr_credentials_secret_arn,
      var.bearer_token_secret_arn != null ? var.bearer_token_secret_arn : "arn:aws:secretsmanager:${var.region}:*:secret:dummy-*"
    ]
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

  # SSM permissions for ScyllaDB keyspace configuration only
  statement {
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:DescribeInstanceInformation"
    ]
    resources = ["*"]
  }
  
  # VPC permissions for CodeBuild VPC configuration
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
      "ec2:CreateNetworkInterfacePermission"
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


