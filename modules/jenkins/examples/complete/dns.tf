##########################################
# Route53 Hosted Zone for FQDN
##########################################
data "aws_route53_zone" "root" {
  name         = local.fully_qualified_domain_name
  private_zone = false
}

# resource "aws_route53_zone" "root" {
#   name = local.fully_qualified_domain_name
#   #checkov:skip=CKV2_AWS_38: DNSSEC signing disabled by design
#   #checkov:skip=CKV2_AWS_39: Query logging disabled by design
# }

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.root.id
  name    = "jenkins.${data.aws_route53_zone.root.name}"
  type    = "A"
  alias {
    name                   = module.jenkins.jenkins_alb_dns_name
    zone_id                = module.jenkins.jenkins_alb_zone_id
    evaluate_target_health = true
  }
}

##########################################
# Jenkins Certificate Management
##########################################

resource "aws_acm_certificate" "jenkins" {
  domain_name       = "jenkins.${data.aws_route53_zone.root.name}"
  validation_method = "DNS"

  tags = {
    Environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "jenkins_cert" {
  for_each = {
    for dvo in aws_acm_certificate.jenkins.domain_validation_options : dvo.domain_name => {
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

# tflint-ignore: terraform_required_providers
resource "aws_acm_certificate_validation" "jenkins" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.jenkins.arn
  validation_record_fqdns = [for record in aws_route53_record.jenkins_cert : record.fqdn]
}
