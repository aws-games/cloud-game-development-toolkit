##########################################
# Route53 DNS Records
##########################################

# Public route53 hosted zone for external DNS resolution
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

# Public P4 Server Record
resource "aws_route53_record" "p4_server_public" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.perforce_fqdn
  type    = "A"
  ttl     = 300
  #checkov:skip=CKV2_AWS_23:The attached resource is managed by CGD Toolkit
  records = [module.perforce.p4_server_eip_public_ip]
}

# Public TeamCity Record
resource "aws_route53_record" "teamcity_public" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.teamcity_fqdn
  type    = "A"

  alias {
    name                   = module.teamcity.external_alb_dns_name
    zone_id                = module.teamcity.external_alb_zone_id
    evaluate_target_health = true
  }
}

##########################################
# Certificate Management
##########################################

resource "aws_acm_certificate" "shared" {
  domain_name = var.route53_public_hosted_zone_name
  subject_alternative_names = [
    local.perforce_fqdn,
    local.p4_auth_fqdn,
    local.teamcity_fqdn,
    local.unity_accelerator_fqdn,
    local.unity_license_fqdn
  ]
  validation_method = "DNS"

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-certificate"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.shared.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "shared" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.shared.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}
