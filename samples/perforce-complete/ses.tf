# Create SES Email Identities
resource "awscc_ses_email_identity" "sender" {
  email_identity = var.sender_email_address
}
resource "awscc_ses_email_identity" "receiver" {
  email_identity = var.receiver_email_address
}

# Create SES Domain Identities
resource "awscc_ses_email_identity" "domain" {
  email_identity = var.root_domain_name
  dkim_attributes = {
    signing_enabled = true
  }
  dkim_signing_attributes = {
    next_signing_key_length = "RSA_2048_BIT" // Valid values are either 'RSA_1024_BIT' or 'RSA_2048_BIT'
  }
}

# Create CNAME Records in Amazon Route 53 for Domain Verification using DKIM Tokens
resource "aws_route53_record" "dkim_1" {
  count           = var.enable_dkim_auto_verification ? 1 : 0
  zone_id         = data.aws_route53_zone.root.zone_id
  allow_overwrite = true
  name            = awscc_ses_email_identity.domain.dkim_dns_token_name_1
  ttl             = 172800
  type            = "CNAME"

  records = [
    awscc_ses_email_identity.domain.dkim_dns_token_value_1
  ]
}
resource "aws_route53_record" "dkim_2" {
  count           = var.enable_dkim_auto_verification ? 1 : 0
  zone_id         = data.aws_route53_zone.root.zone_id
  allow_overwrite = true
  name            = awscc_ses_email_identity.domain.dkim_dns_token_name_2
  ttl             = 172800
  type            = "CNAME"

  records = [
    awscc_ses_email_identity.domain.dkim_dns_token_value_2
  ]
}
resource "aws_route53_record" "dkim_3" {
  count           = var.enable_dkim_auto_verification ? 1 : 0
  zone_id         = data.aws_route53_zone.root.zone_id
  allow_overwrite = true
  name            = awscc_ses_email_identity.domain.dkim_dns_token_name_3
  ttl             = 172800
  type            = "CNAME"

  records = [
    awscc_ses_email_identity.domain.dkim_dns_token_value_3
  ]
}

# (Optional) Export DKIM tokens to validate domain with external DNS provider (e.g. GoDaddy, Google, etc.)
resource "local_file" "dkim" {
  count    = var.export_dkim_tokens ? 1 : 0
  filename = "${path.root}/SES-DNS-Validation/${var.root_domain_name}-dkim-dns-records.txt"
  content  = <<-EOF
  - DNS Token 1 -
  record type = CNAME
  name = ${awscc_ses_email_identity.domain.dkim_dns_token_name_1}
  value = ${awscc_ses_email_identity.domain.dkim_dns_token_value_1}

  - DNS Token 2 -
  record type = CNAME
  name = ${awscc_ses_email_identity.domain.dkim_dns_token_name_2}
  value = ${awscc_ses_email_identity.domain.dkim_dns_token_value_2}

  - DNS Token 3 -
  record type = CNAME
  name = ${awscc_ses_email_identity.domain.dkim_dns_token_name_3}
  value = ${awscc_ses_email_identity.domain.dkim_dns_token_value_3}

  EOF
}


# Create SMTP User Creds following AWS Docs: https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html
resource "random_string" "swarm_ses_smtp_user" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_iam_user" "swarm_ses_smtp_user" {
  name          = "swarm-ses-smtp-user-${random_string.swarm_ses_smtp_user.result}"
  path          = "/SES_Users/"
  force_destroy = true # prevents DeleteConflict Error
}

resource "aws_iam_access_key" "swarm_ses_smtp_user" {
  user = aws_iam_user.swarm_ses_smtp_user.name
}

# resource "aws_iam_group" "swarm_ses_smtp_users" {
#   name = "AWSSESSendingGroupDoNotRename"
# }
# resource "aws_iam_group_membership" "swarm_ses_smtp_users" {
#   name = "swarm-ses-smtp-user-membership"

#   users = [
#     aws_iam_user.swarm_ses_smtp_user.name,
#   ]

#   group = aws_iam_group.swarm_ses_smtp_users.name
# }

data "aws_iam_policy_document" "swarm_ses_smtp_user_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendTemplatedEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "swarm_ses_smtp_user_policy" {
  name = "swarm-ses-smtp-user-policy"
  # name   = "AmazonSesSendingAccess"
  user   = aws_iam_user.swarm_ses_smtp_user.name
  policy = data.aws_iam_policy_document.swarm_ses_smtp_user_policy.json

}


