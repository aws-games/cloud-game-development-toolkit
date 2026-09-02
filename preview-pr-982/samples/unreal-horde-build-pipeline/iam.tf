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
