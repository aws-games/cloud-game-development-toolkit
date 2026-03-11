##########################################
# Fetch Route53 Public Hosted Zone for FQDN
##########################################
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

##########################################
# DDC External (Public) DNS
##########################################
# DNS records are created automatically by External-DNS EKS addon
# in each region based on LoadBalancer service annotations



##########################################
# DDC Certificate Management
##########################################
# Certificate for primary region NLB (us-east-1)
resource "aws_acm_certificate" "ddc_primary" {
  region = local.primary_region
  domain_name = "*.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  subject_alternative_names = [
    "*.monitoring.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  ]

  validation_method = "DNS"

  #checkov:skip=CKV2_AWS_71: Wildcard is necessary for this domain

  tags = {
    environment = local.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate for secondary region NLB (us-west-1)
resource "aws_acm_certificate" "ddc_secondary" {
  region = local.secondary_region
  domain_name = "*.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  subject_alternative_names = [
    "*.monitoring.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  ]

  validation_method = "DNS"

  #checkov:skip=CKV2_AWS_71: Wildcard is necessary for this domain

  tags = {
    environment = local.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records for primary certificate
resource "aws_route53_record" "ddc_cert_primary" {
  for_each = {
    for dvo in aws_acm_certificate.ddc_primary.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.root.id
}

# DNS validation records for secondary certificate
resource "aws_route53_record" "ddc_cert_secondary" {
  for_each = {
    for dvo in aws_acm_certificate.ddc_secondary.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.root.id
}

# Wait for both certificates to be validated
resource "aws_acm_certificate_validation" "ddc_primary" {
  region = local.primary_region
  certificate_arn         = aws_acm_certificate.ddc_primary.arn
  validation_record_fqdns = [for record in aws_route53_record.ddc_cert_primary : record.fqdn]

  lifecycle {
    create_before_destroy = true
  }
  timeouts {
    create = "15m"
  }
}

resource "aws_acm_certificate_validation" "ddc_secondary" {
  region = local.secondary_region
  certificate_arn         = aws_acm_certificate.ddc_secondary.arn
  validation_record_fqdns = [for record in aws_route53_record.ddc_cert_secondary : record.fqdn]

  lifecycle {
    create_before_destroy = true
  }
  timeouts {
    create = "15m"
  }
}
