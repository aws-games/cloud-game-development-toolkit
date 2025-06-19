//do i even need this???? not sure what's carried over by module
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

# Create a record in the Hosted Zone for the TeamCity server
resource "aws_route53_record" "teamcity" {
  zone_id = data.aws_route53_zone.root.id
  name    = "teamcity.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.teamcity.external_alb_dns_name
    zone_id                = module.teamcity.external_alb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "perforce" {
  zone_id = data.aws_route53_zone.root.id
  name    = "perforce.${data.aws_route53_zone.root.name}"
  type    = "A"

  records = [module.perforce.p4_server_eip_public_ip]
  ttl     = 300
}

// for teamcity resources only

resource "aws_acm_certificate" "teamcity" {
  domain_name       = "teamcity.${data.aws_route53_zone.root.name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "teamcity_cert" {
  for_each = {
    for dvo in aws_acm_certificate.teamcity.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "teamcity" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.teamcity.arn
  validation_record_fqdns = [for record in aws_route53_record.teamcity_cert : record.fqdn]
}


