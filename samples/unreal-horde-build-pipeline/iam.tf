##################################################
# Horde Agent — Additional IAM (JT-09)
#
# The Horde module creates the agent instance role but does NOT grant access to
# the sample's runtime secrets. The BuildGraph tasks running on the agents need:
#   * the FSxN fsxadmin password (ONTAP REST API: FlexClone / snapshot), and
#   * the Horde P4 credentials (JSON username/password) to authenticate to P4.
#
# This policy grants secretsmanager:GetSecretValue scoped to the EXACT secret
# ARNs only — never "*".
##################################################

data "aws_iam_policy_document" "agent_secrets_read" {
  statement {
    sid    = "ReadPipelineSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    # Exact ARNs only. The Horde P4 credentials secret and the Perforce module's
    # super/admin secrets are only present when this sample deploys Perforce.
    resources = compact([
      aws_secretsmanager_secret.fsxn_admin.arn,
      local.deploy_perforce ? aws_secretsmanager_secret.horde_p4_credentials[0].arn : "",
      local.deploy_perforce ? module.perforce[0].p4_server_super_password_secret_arn : "",
    ])
  }
}

resource "aws_iam_policy" "agent_secrets_read" {
  name        = "${local.name_prefix}-agent-secrets-read"
  description = "Allow Horde agents to read the FSxN fsxadmin and P4 credential secrets (scoped to exact ARNs)."
  policy      = data.aws_iam_policy_document.agent_secrets_read.json

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-agent-secrets-read"
  })
}

resource "aws_iam_role_policy_attachment" "agent_secrets_read" {
  role       = module.horde.agent_instance_role_name
  policy_arn = aws_iam_policy.agent_secrets_read.arn
}

##################################################
# Agent Configuration Bucket + SSM Associations (JT-10)
#
# Two SSM Associations configure the agent pools by launch template ID:
#   * sync-agent  (Linux)   — mounts the FSxN NFS volume + installs p4 CLI via
#                             an Ansible playbook (config/sync-agent.ansible.yml)
#   * build-agent (Windows) — installs the NFS client + p4.exe via a PowerShell
#                             script (config/build-agent-setup.ps1)
#
# PHASE 2 DEFERRAL:
#   The playbook and PowerShell script live under config/ and are created in
#   Phase 2 (JT-14 / JT-15). They do NOT exist yet. To keep `terraform validate`
#   and `terraform plan` working today, the aws_s3_object uploads are guarded
#   with fileexists() and only created for_each over the files that are present
#   on disk. The SSM Associations still reference the intended S3 object keys so
#   the wiring is complete; once the Phase 2 files land, the objects upload
#   automatically on the next apply. See the TODO(JT-14/JT-15) markers below.
##################################################

resource "aws_s3_bucket" "agent_config" {
  bucket_prefix = "${local.name_prefix}-agent-config-"
  force_destroy = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-agent-config"
  })

  #checkov:skip=CKV_AWS_18:Access logging out of scope for this sample bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication out of scope for this sample
  #checkov:skip=CKV_AWS_21:Versioning out of scope for this sample config bucket
  #checkov:skip=CKV2_AWS_61:Lifecycle configuration out of scope for this sample
  #checkov:skip=CKV2_AWS_62:Event notifications out of scope for this sample
}

resource "aws_s3_bucket_public_access_block" "agent_config" {
  bucket                  = aws_s3_bucket.agent_config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "agent_config" {
  bucket = aws_s3_bucket.agent_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Intended S3 object keys (kept in locals so the SSM Associations and the
# guarded uploads reference the same paths).
locals {
  sync_agent_playbook_key = "config/sync-agent.ansible.yml"
  build_agent_script_key  = "config/build-agent-setup.ps1"

  # TODO(JT-14/JT-15): these files are delivered in Phase 2. fileexists() lets
  # validate/plan pass now; the objects upload once the files exist.
  agent_config_files = {
    (local.sync_agent_playbook_key) = "${path.module}/config/sync-agent.ansible.yml"
    (local.build_agent_script_key)  = "${path.module}/config/build-agent-setup.ps1"
  }
}

resource "aws_s3_object" "agent_config" {
  for_each = {
    for key, src in local.agent_config_files : key => src if fileexists(src)
  }

  bucket = aws_s3_bucket.agent_config.id
  key    = each.key
  source = each.value
  etag   = filemd5(each.value)

  tags = local.tags
}

# --- Sync Agent (Linux) SSM Association ------------------------------------
#
# Uses the AWS-managed AWS-ApplyAnsiblePlaybooks document to pull the playbook
# ZIP/dir from S3 and run it. Targeted by launch template ID so it applies to
# every instance the sync-agent ASG launches.
#
# TODO(JT-14): the referenced playbook object is delivered in Phase 2. Until
# then the object may not exist in the bucket; the association is created now so
# the wiring is complete and validated.
resource "aws_ssm_association" "configure_sync_agent" {
  association_name = "${local.name_prefix}-configure-sync-agent"
  name             = "AWS-ApplyAnsiblePlaybooks"

  targets {
    key    = "tag:aws:ec2launchtemplate:id"
    values = [module.horde.agent_launch_template_ids["sync-agent"]]
  }

  parameters = {
    SourceType = "S3"
    SourceInfo = jsonencode({
      path = "https://${aws_s3_bucket.agent_config.bucket_regional_domain_name}/config/"
    })
    InstallDependencies = "True"
    PlaybookFile        = "sync-agent.ansible.yml"
    ExtraVariables      = "fsxn_nfs_endpoint=${aws_fsx_ontap_storage_virtual_machine.workspace.endpoints[0].nfs[0].dns_name} p4_workspace_junction=${local.fsxn_source_junction_path}"
  }
}

# --- Build Agent (Windows) SSM Association ---------------------------------
#
# Uses the AWS-managed AWS-RunPowerShellScript document. The script body is read
# from the Phase 2 file when present; until then a documented placeholder script
# keeps the association valid so `terraform validate`/`plan` pass.
#
# TODO(JT-15): replace the placeholder body by delivering
# config/build-agent-setup.ps1 in Phase 2. The fileexists() guard swaps in the
# real script automatically once it exists.
resource "aws_ssm_association" "configure_build_agent" {
  association_name = "${local.name_prefix}-configure-build-agent"
  name             = "AWS-RunPowerShellScript"

  targets {
    key    = "tag:aws:ec2launchtemplate:id"
    values = [module.horde.agent_launch_template_ids["build-agent"]]
  }

  parameters = {
    commands = fileexists("${path.module}/config/build-agent-setup.ps1") ? file("${path.module}/config/build-agent-setup.ps1") : "Write-Output 'TODO(JT-15): build-agent-setup.ps1 delivered in Phase 2. Placeholder until then.'"
  }
}
