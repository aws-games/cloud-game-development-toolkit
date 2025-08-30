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
# Route DDC service traffic to the DDC NLB
resource "aws_route53_record" "external_ddc_service" {
  zone_id = data.aws_route53_zone.root.id
  name    = local.ddc_fully_qualified_domain_name
  type    = "A"
  alias {
    name                   = module.unreal_cloud_ddc.nlb_dns_name
    zone_id                = module.unreal_cloud_ddc.nlb_zone_id
    evaluate_target_health = true
  }
}

# Route monitoring traffic to the monitoring ALB
resource "aws_route53_record" "external_ddc_monitoring" {
  count   = try(module.unreal_cloud_ddc.monitoring_alb_dns_name, null) != null ? 1 : 0
  zone_id = data.aws_route53_zone.root.id
  name    = local.monitoring_fully_qualified_domain_name
  type    = "A"
  alias {
    name                   = module.unreal_cloud_ddc.monitoring_alb_dns_name
    zone_id                = module.unreal_cloud_ddc.monitoring_alb_zone_id
    evaluate_target_health = true
  }
}

##########################################
# DDC Certificate Management
##########################################
resource "aws_acm_certificate" "ddc" {
  domain_name = "*.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"

  validation_method = "DNS"

  #checkov:skip=CKV2_AWS_71: Wildcard is necessary for this domain

  tags = {
    environment = local.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "ddc_cert" {
  for_each = {
    for dvo in aws_acm_certificate.ddc.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "ddc" {
  certificate_arn         = aws_acm_certificate.ddc.arn
  validation_record_fqdns = [for record in aws_route53_record.ddc_cert : record.fqdn]

  lifecycle {
    create_before_destroy = true
  }
  timeouts {
    create = "15m"
  }
}