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
