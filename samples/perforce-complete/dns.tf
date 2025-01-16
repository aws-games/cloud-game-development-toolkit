##########################################
# Perforce DNS
##########################################
resource "aws_route53_zone" "perforce_private_hosted_zone" {
  name = "perforce.${data.aws_route53_zone.root.name}"
  #checkov:skip=CKV2_AWS_38: Hosted zone is private (vpc association)
  #checkov:skip=CKV2_AWS_39: Query logging disabled by design
  vpc {
    vpc_id = aws_vpc.perforce_vpc.id
  }
}

# Route all external web service traffic to the NLB
resource "aws_route53_record" "external_perforce_web_services" {
  zone_id = data.aws_route53_zone.root.id
  name    = "*.perforce.${data.aws_route53_zone.root.name}"
  type    = "A"
  alias {
    name                   = aws_lb.perforce.dns_name
    zone_id                = aws_lb.perforce.zone_id
    evaluate_target_health = true
  }
}

# Route all internal web service traffic to the ALB
resource "aws_route53_record" "internal_perforce_web_services" {
  zone_id = aws_route53_zone.perforce_private_hosted_zone.id
  name    = "*.${aws_route53_zone.perforce_private_hosted_zone.name}"
  type    = "A"
  alias {
    name                   = aws_lb.perforce_web_services.dns_name
    zone_id                = aws_lb.perforce_web_services.zone_id
    evaluate_target_health = true
  }
}

# Route all external Helix Core traffic to the NLB
resource "aws_route53_record" "external_helix_core" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "perforce.${data.aws_route53_zone.root.name}"
  type    = "A"
  alias {
    name                   = aws_lb.perforce.dns_name
    zone_id                = aws_lb.perforce.zone_id
    evaluate_target_health = true
  }
}

# Route all internal Helix Core traffic to the instance
resource "aws_route53_record" "internal_helix_core" {
  zone_id = aws_route53_zone.perforce_private_hosted_zone.zone_id
  name    = aws_route53_zone.perforce_private_hosted_zone.name
  type    = "A"
  records = [module.perforce_helix_core.helix_core_private_ip]
  ttl     = 300
}

##########################################
# Helix Certificate Management
##########################################
resource "aws_acm_certificate" "perforce" {
  domain_name               = "perforce.${var.root_domain_name}"
  subject_alternative_names = ["*.perforce.${var.root_domain_name}"]

  validation_method = "DNS"

  tags = {
    environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "perforce_cert" {
  for_each = {
    for dvo in aws_acm_certificate.perforce.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "perforce" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.perforce.arn
  validation_record_fqdns = [for record in aws_route53_record.perforce_cert : record.fqdn]
}
