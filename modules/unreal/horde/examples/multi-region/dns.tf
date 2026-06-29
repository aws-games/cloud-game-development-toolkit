data "aws_route53_zone" "root" {
  name         = var.root_domain_name
  private_zone = false
}

resource "aws_acm_certificate" "horde" {
  domain_name       = "horde.${var.root_domain_name}"
  validation_method = "DNS"
  tags              = local.tags
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.horde.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "horde" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.horde.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_route53_record" "horde_external" {
  zone_id = data.aws_route53_zone.root.id
  name    = "horde.${var.root_domain_name}"
  type    = "A"
  alias {
    name                   = module.horde.external_alb_dns_name
    zone_id                = module.horde.external_alb_zone_id
    evaluate_target_health = true
  }
}

# Private hosted zone for agents to reach Horde via internal ALB
resource "aws_route53_zone" "horde_private" {
  name = "horde.${var.root_domain_name}"

  vpc {
    vpc_id = aws_vpc.primary.id
  }
}

resource "aws_route53_record" "horde_internal" {
  zone_id = aws_route53_zone.horde_private.zone_id
  name    = aws_route53_zone.horde_private.name
  type    = "A"
  alias {
    name                   = module.horde.internal_alb_dns_name
    zone_id                = module.horde.internal_alb_zone_id
    evaluate_target_health = true
  }
}
