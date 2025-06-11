variable "root_domain_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where Unity Accelerator record should be created."
}

##########################################
# Route53 Hosted Zone for Root
##########################################
data "aws_route53_zone" "root" {
  name         = var.root_domain_name
  private_zone = false
}

# Create a record in the Hosted Zone for the Unity Accelerator cache
resource "aws_route53_record" "unity_accelerator_cache" {
  zone_id = data.aws_route53_zone.root.id
  name    = "cache.unity.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unity_accelerator.external_nlb_dns_name
    zone_id                = module.unity_accelerator.external_nlb_zone_id
    evaluate_target_health = false
  }
}

# Create a record in the Hosted Zone for the Unity Accelerator dashboard
resource "aws_route53_record" "unity_accelerator_dashboard" {
  zone_id = data.aws_route53_zone.root.id
  name    = "dashboard.unity.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unity_accelerator.external_alb_dns_name
    zone_id                = module.unity_accelerator.external_alb_zone_id
    evaluate_target_health = false
  }
}

# Create a certificate for Unity Accelerator dashboard
resource "aws_acm_certificate" "unity_accelerator" {
  domain_name       = "dashboard.unity.${data.aws_route53_zone.root.name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "unity_accelerator_cert" {
  for_each = {
    for dvo in aws_acm_certificate.unity_accelerator.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "unity_accelerator" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.unity_accelerator.arn
  validation_record_fqdns = [for record in aws_route53_record.unity_accelerator_cert : record.fqdn]
}
