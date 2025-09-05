resource "aws_launch_template" "unreal_horde_agent_template" {
  for_each    = var.agents
  name_prefix = "unreal_horde_agent-${each.key}"
  description = "Launch template for ${each.key} Unreal Horde Agents"

  image_id      = each.value.ami
  instance_type = each.value.instance_type
  ebs_optimized = true

  dynamic "block_device_mappings" {
    for_each = each.value.block_device_mappings
    content {
      device_name = block_device_mappings.value.device_name
      ebs {
        volume_size = block_device_mappings.value.ebs.volume_size
        volume_type = "gp2"
      }
    }
  }

  vpc_security_group_ids = [aws_security_group.unreal_horde_agent_sg[0].id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
  iam_instance_profile {
    arn = aws_iam_instance_profile.unreal_horde_agent_instance_profile[0].arn
  }
}

resource "aws_autoscaling_group" "unreal_horde_agent_asg" {
  for_each    = aws_launch_template.unreal_horde_agent_template
  name_prefix = "unreal_horde_agents-${each.key}-"

  launch_template {
    id      = each.value.id
    version = "$Latest"
  }

  vpc_zone_identifier = var.unreal_horde_service_subnets

  min_size = var.agents[each.key].min_size
  max_size = var.agents[each.key].max_size

  tag {
    key                 = "Name"
    value               = "${each.key} Horde Agent"
    propagate_at_launch = true
  }

  depends_on = [aws_ecs_service.unreal_horde]
}

data "aws_iam_policy_document" "ec2_trust_relationship" {
  count = length(var.agents) > 0 ? 1 : 0
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "horde_agents_s3_policy" {
  count = length(var.agents) > 0 ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetEncryptionConfiguration"
    ]
    resources = [
      aws_s3_bucket.ansible_playbooks[0].arn,
      "${aws_s3_bucket.ansible_playbooks[0].arn}/*"
    ]
  }
}

resource "aws_iam_policy" "horde_agents_s3_policy" {
  count       = length(var.agents) > 0 ? 1 : 0
  name        = "${var.project_prefix}-horde-agents-s3-policy"
  description = "Policy granting Horde Agent EC2 instances access to Amazon S3."
  policy      = data.aws_iam_policy_document.horde_agents_s3_policy[0].json
}

# Instance Role
resource "aws_iam_role" "unreal_horde_agent_default_role" {
  count              = length(var.agents) > 0 ? 1 : 0
  name               = "unreal-horde-agent-default-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_relationship[0].json

  tags = local.tags
}

resource "aws_iam_role_policy_attachments_exclusive" "unreal_horde_agent_policy_attachments" {
  count      = length(var.agents) > 0 ? 1 : 0
  role_name  = aws_iam_role.unreal_horde_agent_default_role[0].name
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    aws_iam_policy.horde_agents_s3_policy[0].arn
  ]
}

# Instance Profile
resource "aws_iam_instance_profile" "unreal_horde_agent_instance_profile" {
  count = length(var.agents) > 0 ? 1 : 0
  name  = "unreal-horde-agent-instance-profile"
  role  = aws_iam_role.unreal_horde_agent_default_role[0].name
}

resource "random_string" "unreal_horde_ansible_playbooks_bucket_suffix" {
  count   = length(var.agents) > 0 ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "ansible_playbooks" {
  count  = length(var.agents) > 0 ? 1 : 0
  bucket = "unreal-horde-ansible-playbooks-${random_string.unreal_horde_ansible_playbooks_bucket_suffix[0].id}"

  #checkov:skip=CKV_AWS_144: Cross-region replication not necessary
  #checkov:skip=CKV_AWS_145: KMS encryption with CMK not currently supported
  #checkov:skip=CKV_AWS_18: S3 access logs not necessary
  #checkov:skip=CKV2_AWS_62: Event notifications not necessary
  #checkov:skip=CKV2_AWS_61: Lifecycle configuration not necessary
  #checkov:skip=CKV2_AWS_6: Public access block conditionally defined
  #checkov:skip=CKV_AWS_21: Versioning enabled conditionally

  tags                = local.tags
  object_lock_enabled = true
  force_destroy       = true

}

resource "aws_s3_bucket_versioning" "ansible_playbooks_versioning" {
  count = length(var.agents) > 0 ? 1 : 0

  bucket = aws_s3_bucket.ansible_playbooks[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ansible_playbooks_bucket_public_block" {
  count = length(var.agents) > 0 ? 1 : 0

  depends_on = [
    aws_s3_bucket.ansible_playbooks[0]
  ]
  bucket                  = aws_s3_bucket.ansible_playbooks[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "unreal_horde_agent_playbook" {
  count         = length(var.agents) > 0 ? 1 : 0
  bucket        = aws_s3_bucket.ansible_playbooks[0].id
  key           = "/agent/horde-agent.ansible.yml"
  source        = "${path.module}/config/agent/horde-agent.ansible.yml"
  etag          = filemd5("${path.module}/config/agent/horde-agent.ansible.yml")
  force_destroy = true
}

resource "aws_s3_object" "unreal_horde_agent_service" {
  count         = length(var.agents) > 0 ? 1 : 0
  bucket        = aws_s3_bucket.ansible_playbooks[0].id
  key           = "/agent/horde-agent.service"
  source        = "${path.module}/config/agent/horde-agent.service"
  etag          = filemd5("${path.module}/config/agent/horde-agent.service")
  force_destroy = true
}

resource "aws_ssm_document" "ansible_run_document" {
  count         = length(var.agents) > 0 ? 1 : 0
  document_type = "Command"
  name          = "AnsibleRun"
  content       = file("${path.module}/config/ssm/AnsibleRunCommand.json")
  tags          = local.tags
}

resource "aws_ssm_association" "configure_unreal_horde_agent" {
  count            = length(var.agents) > 0 ? 1 : 0
  association_name = "ConfigureUnrealHordeAgent"
  name             = aws_ssm_document.ansible_run_document[0].name
  parameters = {
    SourceInfo     = "{\"path\":\"https://${aws_s3_bucket.ansible_playbooks[0].bucket_domain_name}/agent/\"}"
    PlaybookFile   = "horde-agent.ansible.yml"
    ExtraVariables = "horde_server_url=${var.fully_qualified_domain_name} dotnet_runtime_version=${var.agent_dotnet_runtime_version}"
  }

  output_location {
    s3_bucket_name = aws_s3_bucket.ansible_playbooks[0].bucket
    s3_key_prefix  = "logs"
  }

  targets {
    key    = "tag:aws:autoscaling:groupName"
    values = values(aws_autoscaling_group.unreal_horde_agent_asg)[*].name
  }

  # Wait for service to be ready before attempting enrollment
  depends_on = [aws_ecs_service.unreal_horde]
}
