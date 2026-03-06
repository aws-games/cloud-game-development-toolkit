################################################################################
# CodeBuild Project for DDC Deployment (Deploy Only)
################################################################################

resource "aws_codebuild_project" "ddc_deployer" {
  name         = "${local.name_prefix}-ddc-deployer"
  description  = "Deploy Unreal Cloud DDC via Helm to EKS cluster"
  service_role = aws_iam_role.codebuild_role.arn

  depends_on = [time_sleep.iam_propagation]

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
      value = var.force_codebuild_run ? "true" : "false"
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
    location = "${aws_s3_bucket.assets.bucket}/deploy/assets.zip"
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

  depends_on = [time_sleep.iam_propagation]

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
      value = "15"
    }

    environment_variable {
      name  = "DEBUG"
      value = var.force_codebuild_run ? "true" : "false"
    }
  }

  source {
    type = "S3"
    location = "${aws_s3_bucket.assets.bucket}/test/assets.zip"
    buildspec = file("${path.module}/buildspecs/test-ddc.yml")
  }

  tags = var.tags
}

################################################################################
# Terraform Actions for DDC Deployment
#
# CONTROL LAYERS:
# Layer 1: Module existence - ddc_app_config present → submodule deployed
# Layer 2: Testing control - enable_*_validation controls test CodeBuild
# Layer 3: Debug override - debug=true forces single-region tests only (prevents duplication)
#
# DEPLOYMENT: Always runs when ddc_app_config is present (no killswitch needed)
# TESTING DEFAULTS:
# - enable_single_region_validation = true (valuable for both single + multi-region)
# - enable_multi_region_validation = false (only enable in primary region)
#
# MULTI-REGION DEPLOYMENT PATTERN:
# - Two simultaneous single-region deployments
# - Each region: deploy CodeBuild + single-region tests (default)
# - Primary region: multi-region tests (peer_region_ddc_endpoint=null)
# - Secondary region: multi-region tests blocked (peer_region_ddc_endpoint=set)
#
# RECOMMENDED MULTI-REGION CONFIGURATION:
# Primary region (us-east-1):
#   enable_single_region_validation = true   # Default
#   enable_multi_region_validation = true    # Enable cross-region tests
#   peer_region_ddc_endpoint = null          # Identifies as primary
#
# Secondary region (us-west-2):
#   enable_single_region_validation = true   # Default  
#   enable_multi_region_validation = false   # No multi-region tests needed
#   peer_region_ddc_endpoint = "us-east-1.ddc.example.com"
#
# DEBUG BEHAVIOR:
# - debug=true forces single-region tests to run via timestamp
# - debug=true does NOT force multi-region tests (prevents duplication)
# - Only enable debug=true in ONE region for multi-region deployments
################################################################################

# Deploy action - always runs when ddc_app_config present
# Runs on first apply + when changes detected (normal Terraform behavior)
resource "terraform_data" "deploy_trigger" {
  input = merge(
    {
      cluster_name = var.cluster_name
      cluster_version = var.kubernetes_version  # Trigger redeployment on K8s upgrades
      ddc_version  = var.ddc_application_config.helm_chart
      config_hash  = sha256(jsonencode(var.ddc_application_config))
      values_hash  = local_file.ddc_helm_values.content_md5
      buildspec_hash = filemd5("${path.module}/buildspecs/deploy-ddc.yml")
      deploy_assets_hash = data.archive_file.deploy_assets.output_md5  # Only deploy assets
    },
    var.force_codebuild_run ? { debug_timestamp = timestamp() } : {}
  )

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.deploy_ddc]
    }
  }

  depends_on = [
    aws_s3_object.deploy_assets,  # Only depend on deploy assets
    time_sleep.iam_propagation    # Wait for IAM permissions to propagate
  ]
}

# Test action - controlled by validation flags + multi-region logic
# SINGLE-REGION: enable_single_region_validation=true (default) + debug override
# MULTI-REGION: enable_multi_region_validation=true (primary region only, no debug override)
resource "terraform_data" "test_trigger" {
  # Multi-region killswitch: multi-region tests only in primary region (peer_region_ddc_endpoint=null)
  count = (
    (var.ddc_application_config.enable_single_region_validation) ||
    (var.ddc_application_config.enable_multi_region_validation && var.ddc_application_config.peer_region_ddc_endpoint == null)
  ) ? 1 : 0

  input = merge(
    {
      # Test-specific changes (only trigger test)
      test_config_hash = sha256(jsonencode({
        dns_endpoint = var.ddc_dns_endpoint
        bearer_token_secret = var.bearer_token_secret_arn
        peer_endpoint = var.ddc_application_config.peer_region_ddc_endpoint
        single_region_validation = var.ddc_application_config.enable_single_region_validation
        multi_region_validation = var.ddc_application_config.enable_multi_region_validation
      }))
      test_buildspec_hash = filemd5("${path.module}/buildspecs/test-ddc.yml")
      test_assets_hash = data.archive_file.test_assets.output_md5  # Only test assets
      
      # Deploy changes that should trigger tests (deploy changes → test runs)
      deploy_config_hash = sha256(jsonencode(var.ddc_application_config))
      deploy_values_hash = local_file.ddc_helm_values.content_md5
      deploy_buildspec_hash = filemd5("${path.module}/buildspecs/deploy-ddc.yml")
      deploy_assets_hash = data.archive_file.deploy_assets.output_md5  # Deploy script changes should trigger tests
    },
    # Debug override: Only forces single-region tests (prevents multi-region duplication)
    (var.force_codebuild_run && var.ddc_application_config.enable_single_region_validation) ? { debug_timestamp = timestamp() } : {}
  )

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.test_ddc]
    }
  }

  depends_on = [terraform_data.deploy_trigger, time_sleep.iam_propagation]  # NOTE: deploy_trigger dependency is ignored due to Terraform Actions bug
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
    aws_s3_object.deploy_assets,
    aws_s3_object.test_assets
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
    resources = [
      "${aws_s3_bucket.assets.arn}/deploy/assets.zip",
      "${aws_s3_bucket.assets.arn}/test/assets.zip"
    ]
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

# IAM permission propagation delay
resource "time_sleep" "iam_propagation" {
  depends_on = [
    aws_iam_role.codebuild_role,
    aws_iam_role_policy.codebuild_policy
  ]
  
  create_duration = "60s"
}


