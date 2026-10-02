##################################################
# Horde Agent — Additional IAM
#
# The Horde module creates the agent instance role but does NOT grant access to
# the sample's runtime secrets. The BuildGraph tasks running on the agents need:
#   * the FSxN fsxadmin password (ONTAP REST API: FlexClone / snapshot), and
#   * the Horde P4 credentials (JSON username/password) to authenticate to P4
#     and mint a `p4 login` ticket (var.horde_p4_credentials_secret_arn).
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
    # Exact ARNs only. Agents read the FSxN fsxadmin secret (ONTAP REST API) and
    # the Horde P4 credentials secret (the SAME secret the agents read to mint a
    # login ticket). The Perforce super/admin password is NOT an agent-side
    # secret and is intentionally excluded.
    resources = compact([
      aws_secretsmanager_secret.fsxn_admin.arn,
      var.horde_p4_credentials_secret_arn != null ? var.horde_p4_credentials_secret_arn : "",
    ])
  }

  # Igroup self-heal (finding #0004). The hydrator refuses to add itself to a
  # single-host SOURCE-LUN igroup that already contains a foreign initiator, to
  # avoid two NTFS writers. To safely auto-remove a STALE initiator left by a
  # TERMINATED previous hydrator, OntapSan.psm1's Get-TerminatedInitiators parses
  # the instance-id from the iqn.1991-05.com.microsoft:i-<id> initiator and calls
  # ec2:DescribeInstances to confirm the instance is 'terminated' (the ONLY state
  # it will remove on; alive/unattributable/inconclusive all REFUSE).
  #
  # This is a SEPARATE statement ON PURPOSE (its own SID, its own actions/
  # resources) rather than being merged into ReadPipelineSecrets above. Merging
  # unrelated grants into one statement is the #998-class coupling we are
  # avoiding: it entangles the tightly-scoped secret ARNs with an action that
  # cannot be resource-scoped, making the whole statement harder to reason about
  # and to tighten later. ec2:DescribeInstances is a read-only, account-wide
  # describe with no ARN-level resource scoping, so resources must be ["*"].
  statement {
    sid    = "DescribeInstancesForIgroupSelfHeal"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
    ]
    # ec2:DescribeInstances does not support resource-level permissions; "*" is
    # the only valid scoping. It is a read-only describe (no mutation).
    resources = ["*"]
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
