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
      var.horde_p4_credentials_secret_arn != null ? var.horde_p4_credentials_secret_arn : "",
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
# Horde Agent — Agent Config Bucket Read
#
# The sync-agent SSM Association uses AWS-ApplyAnsiblePlaybooks, which pulls the
# playbook from the agent config S3 bucket. The Horde module's agent instance
# role does NOT grant access to this sample-created bucket, so SSM's
# downloadContent step fails with AccessDenied (s3:ListBucket). This policy
# grants the exact read access needed, scoped to the agent config bucket only:
#   * s3:ListBucket on the bucket ARN
#   * s3:GetObject on the bucket objects
# The bucket uses SSE-S3 (AES256), so no kms:Decrypt is required.
##################################################

data "aws_iam_policy_document" "agent_config_read" {
  statement {
    sid       = "ListAgentConfigBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.agent_config.arn]
  }

  statement {
    sid       = "GetAgentConfigObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.agent_config.arn}/*"]
  }
}

resource "aws_iam_policy" "agent_config_read" {
  name        = "${local.name_prefix}-agent-config-read"
  description = "Allow Horde agents to read the agent config bucket (Ansible playbook) via SSM. Scoped to the bucket only."
  policy      = data.aws_iam_policy_document.agent_config_read.json

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-agent-config-read"
  })
}

resource "aws_iam_role_policy_attachment" "agent_config_read" {
  role       = module.horde.agent_instance_role_name
  policy_arn = aws_iam_policy.agent_config_read.arn
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

  # SSE-S3 (AES256) rather than SSE-KMS: this is a non-sensitive sample config
  # bucket (it holds the sync-agent Ansible playbook only). Using SSE-S3
  # eliminates the KMS decrypt dependency for the agent instance role — the
  # role only needs s3:GetObject/s3:ListBucket to pull the playbook via SSM
  # AWS-ApplyAnsiblePlaybooks. No kms:Decrypt required.
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Intended S3 object keys (kept in locals so the SSM Associations and the
# guarded uploads reference the same paths).
#
# NOTE: the Windows build-agent script is delivered to instances INLINE via
# templatefile() in the AWS-RunPowerShellScript association (see below), so it
# is intentionally NOT uploaded as an S3 object. Only the Linux Ansible
# playbook — which AWS-ApplyAnsiblePlaybooks pulls from S3 — is uploaded here.
locals {
  sync_agent_playbook_key = "config/sync-agent.ansible.yml"

  agent_config_files = {
    (local.sync_agent_playbook_key) = "${path.module}/config/sync-agent.ansible.yml"
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
# Uses the AWS-managed AWS-RunPowerShellScript document. The script body is
# rendered from config/build-agent-setup.ps1.tpl via templatefile() at apply
# time, injecting the same four NON-secret runtime values the Linux sync-agent
# association receives (FSxN NFS endpoint, workspace junction, P4PORT, P4USER).
# This makes Windows symmetric with Linux — the script no longer scrapes EC2
# tags/IMDS. The P4 PASSWORD is NEVER injected; it stays in Secrets Manager.
#
# p4_port is local.perforce_endpoint, which already coalesces to the deployed
# P4 server's ssl:<ip>:1666 or the user-supplied existing endpoint. When no
# Perforce endpoint exists it is null; templatefile coerces null to "" and the
# script skips the P4PORT step with a warning (idempotent, non-fatal).
resource "aws_ssm_association" "configure_build_agent" {
  association_name = "${local.name_prefix}-configure-build-agent"
  name             = "AWS-RunPowerShellScript"

  targets {
    key    = "tag:aws:ec2launchtemplate:id"
    values = [module.horde.agent_launch_template_ids["build-agent"]]
  }

  parameters = {
    commands = templatefile("${path.module}/config/build-agent-setup.ps1.tpl", {
      fsxn_nfs_endpoint     = aws_fsx_ontap_storage_virtual_machine.workspace.endpoints[0].nfs[0].dns_name
      p4_workspace_junction = local.fsxn_source_junction_path
      p4_port               = local.perforce_endpoint == null ? "" : local.perforce_endpoint
      p4_user               = local.horde_p4_username
      # Horde server URL the agent must enroll against. The base module Windows
      # user_data (agent-config.ps1) runs HordeAgent.exe SetServer against this
      # URL, BUT on this AMI its `choco install dotnet-6.0-runtime` fails (choco
      # is not present at user_data time), so the .NET 6 runtime the agent needs
      # is missing and SetServer/Service-Install never complete — the agent
      # never enrolls. This extension script (which DOES install choco) installs
      # the .NET 6 runtime and completes SetServer + Service Install/Start.
      # Uses the public HTTPS FQDN (matches the durable agent.json the base
      # user_data writes). Sample-side fix only; no modules/ change.
      horde_server_url = "https://${local.horde_public_fqdn}"
    })
  }
}
