##########################################
# Route53 Hosted Zone for FQDN
##########################################
data "aws_route53_zone" "root" {
  name         = var.root_domain_name
  private_zone = false
}

resource "aws_route53_record" "unreal_horde" {
  zone_id = data.aws_route53_zone.root.id
  name    = data.aws_route53_zone.root.name
  type    = "A"
  alias {
    name                   = module.unreal_horde.alb_dns_name
    zone_id                = module.unreal_horde.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "unreal_horde" {
  domain_name       = "horde.${var.root_domain_name}"
  validation_method = "DNS"

  tags = {
    Environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_record" "unreal_horde_cert" {
  for_each = {
    for dvo in aws_acm_certificate.unreal_horde.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "unreal_horde" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.unreal_horde.arn
  validation_record_fqdns = [for record in aws_route53_record.unreal_horde_cert : record.fqdn]
}
