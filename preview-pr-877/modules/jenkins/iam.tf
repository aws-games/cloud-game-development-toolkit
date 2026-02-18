# - Random Strings to prevent naming conflicts -
resource "random_string" "jenkins" {
  length  = 4
  special = false
  upper   = false
}
resource "random_string" "build_farm" {
  length  = 4
  special = false
  upper   = false
}
resource "random_string" "fsxz" {
  length  = 4
  special = false
  upper   = false
}


# - Trust Relationships -
#  EC2
data "aws_iam_policy_document" "ec2_trust_relationship" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
#  ECS - Tasks
data "aws_iam_policy_document" "ecs_tasks_trust_relationship" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# - Policies -
# Jenkins
data "aws_iam_policy_document" "jenkins_default_policy" {
  count = var.create_jenkins_default_policy ? 1 : 0
  # ECS
  statement {
    sid    = "ECSExec"
    effect = "Allow"
    actions = [
      "ssmmessages:OpenDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:CreateControlChannel"
    ]
    resources = [
      "*"
    ]
  }
  # EFS
  statement {
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
      "elasticfilesystem:ClientMount"
    ]
    resources = [
      aws_efs_file_system.jenkins_efs_file_system.arn
    ]
  }
  # Secrets Manager
  dynamic "statement" {
    for_each = length(var.jenkins_agent_secret_arns) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:GetSecretValue",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:DescribeSecret"
      ]
      resources = var.jenkins_agent_secret_arns
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:GetRandomPassword",
      "secretsmanager:BatchGetSecretValue"
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "jenkins_default_policy" {
  count = var.create_jenkins_default_policy ? 1 : 0

  name        = "${var.project_prefix}-jenkins-default-policy"
  description = "Policy granting permissions for Jenkins."
  policy      = data.aws_iam_policy_document.jenkins_default_policy[0].json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-default-policy"
    }
  )
}

# EC2 Fleet Plugin
data "aws_iam_policy_document" "ec2_fleet_plugin_policy" {
  count = var.create_ec2_fleet_plugin_policy && var.build_farm_compute != null ? 1 : 0

  # EC2
  #checkov:skip=CKV_AWS_111:Required permissions from EC2 Fleet
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeSpotFleetInstances",
      "ec2:ModifySpotFleetRequest",
      "ec2:CreateTags",
      "ec2:DescribeRegions",
      "ec2:DescribeInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeSpotFleetRequests",
      "ec2:DescribeFleets",
      "ec2:DescribeFleetInstances",
      "ec2:ModifyFleet",
      "ec2:DescribeInstanceTypes"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:UpdateAutoScalingGroup"
    ]
    resources = values(aws_autoscaling_group.jenkins_build_farm_asg)[*].arn
  }
  #checkov:skip=CKV_AWS_356:Required permissions from EC2 Fleet

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
    ]
    resources = ["*"]
  }

  # IAM
  statement {
    effect = "Allow"
    actions = [
      "iam:ListRoles",
      "iam:ListInstanceProfiles"
    ]
    resources = [
      aws_iam_role.build_farm_role.arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.build_farm_role.arn
    ]
  }
}

resource "aws_iam_policy" "ec2_fleet_plugin_policy" {
  count = var.create_ec2_fleet_plugin_policy ? 1 : 0

  name        = "${var.project_prefix}-ec2-fleet-plugin-policy"
  description = "Policy granting permissions required for Jenkins to use EC2 Fleet plugin."
  policy      = data.aws_iam_policy_document.ec2_fleet_plugin_policy[0].json
}

# Build Farm
data "aws_iam_policy_document" "build_farm_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
      "s3-object-lambda:*"
    ]
    resources = concat(var.existing_artifact_buckets, values(aws_s3_bucket.artifact_buckets)[*].arn)
  }
}
resource "aws_iam_policy" "build_farm_s3_policy" {
  name        = "${var.project_prefix}-build-farm-s3-policy"
  description = "Policy granting Build Farm EC2 instances access to Amazon S3."
  policy      = data.aws_iam_policy_document.build_farm_s3_policy.json
}

# FSXz
data "aws_iam_policy_document" "build_farm_fsxz_policy" {
  statement {
    effect = "Allow"
    actions = [
      "fsx:DeleteSnapshot",
      "fsx:CreateSnapshot",
      "fsx:ListTagsForResource"
    ]
    resources = concat(
      ["arn:aws:fsx:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:snapshot/*/*"],
      [for fs in values(aws_fsx_openzfs_file_system.jenkins_build_farm_fsxz_file_system) : "arn:aws:fsx:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:volume/${fs.id}/*"]
    )
  }
  statement {
    effect = "Allow"
    actions = [
      "fsx:DescribeSnapshots"
    ]
    resources = ["arn:aws:fsx:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:snapshot/*/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "fsx:DescribeVolumes"
    ]
    resources = ["arn:aws:fsx:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:volume/*/*"]
  }
}
resource "aws_iam_policy" "build_farm_fsxz_policy" {
  name        = "${var.project_prefix}-build-farm-fsxz-policy"
  description = "Policy granting Build Farm EC2 instances access to FSxZ."
  policy      = data.aws_iam_policy_document.build_farm_fsxz_policy.json
}

# - Roles -
# Jenkins
resource "aws_iam_role" "jenkins_default_role" {
  count = var.create_jenkins_default_role ? 1 : 0

  name               = "${var.project_prefix}-jenkins-default-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-default-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "default_role" {
  count      = var.create_jenkins_default_role ? 1 : 0
  role       = aws_iam_role.jenkins_default_role[0].name
  policy_arn = aws_iam_policy.jenkins_default_policy[0].arn
}

resource "aws_iam_role" "jenkins_task_execution_role" {
  name = "${var.project_prefix}-jenkins-task-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust_relationship.json

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.jenkins_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# conditionally attach ec2 fleet plugin policy
resource "aws_iam_role_policy_attachment" "ec2_fleet_plugin_policy_attachment" {
  count      = var.create_ec2_fleet_plugin_policy ? 1 : 0
  role       = aws_iam_role.jenkins_default_role[0].name
  policy_arn = aws_iam_policy.ec2_fleet_plugin_policy[0].arn
}

# Build Farm
resource "aws_iam_role" "build_farm_role" {
  name               = "${var.project_prefix}-${var.name}-${random_string.build_farm.result}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_relationship.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "build_farm_role_fsxz_attachment" {
  role       = aws_iam_role.build_farm_role.name
  policy_arn = aws_iam_policy.build_farm_fsxz_policy.arn
}

resource "aws_iam_role_policy_attachment" "build_farm_role_s3_attachment" {
  policy_arn = aws_iam_policy.build_farm_s3_policy.arn
  role       = aws_iam_role.build_farm_role.name
}

# Instance Profiles
resource "aws_iam_instance_profile" "build_farm_instance_profile" {
  name = "${local.name_prefix}-${random_string.build_farm.result}-instance-profile"
  role = aws_iam_role.build_farm_role.name
}
