##########################################
# Fetch Monitoring ALB Details (Primary Region Only)
##########################################
data "aws_lb" "monitoring_alb_primary" {
  provider   = aws.primary
  arn        = module.unreal_cloud_ddc.primary_region.scylla_monitoring_alb_arn
  depends_on = [module.unreal_cloud_ddc]
}

##########################################
# Route53 Hosted Zone for Root
##########################################
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

##########################################
# DDC Service DNS Records (Region-Specific)
##########################################
# Primary DDC service
resource "aws_route53_record" "ddc_primary" {
  depends_on = [module.unreal_cloud_ddc]
  zone_id    = data.aws_route53_zone.root.id
  name       = "ddc-primary.${var.route53_public_hosted_zone_name}"
  type       = "CNAME"
  ttl        = 300
  records    = [module.unreal_cloud_ddc.ddc_endpoints.primary.load_balancer_dns]
}

# Secondary DDC service
resource "aws_route53_record" "ddc_secondary" {
  depends_on = [module.unreal_cloud_ddc]
  zone_id    = data.aws_route53_zone.root.id
  name       = "ddc-secondary.${var.route53_public_hosted_zone_name}"
  type       = "CNAME"
  ttl        = 300
  records    = [module.unreal_cloud_ddc.ddc_endpoints.secondary.load_balancer_dns]
}

##########################################
# Monitoring Service DNS Record (Primary Region Only)
##########################################
# Monitoring service (only in primary region)
resource "aws_route53_record" "monitoring" {
  depends_on = [module.unreal_cloud_ddc]
  zone_id    = data.aws_route53_zone.root.id
  name       = "${local.monitoring_subdomain}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  type       = "A"

  alias {
    name                   = data.aws_lb.monitoring_alb_primary.dns_name
    zone_id                = data.aws_lb.monitoring_alb_primary.zone_id
    evaluate_target_health = false
  }
}

##########################################
# SSL Certificate (Primary Region Only)
##########################################
# Monitoring certificate (only in primary region)
resource "aws_acm_certificate" "monitoring" {
  provider      = aws.primary
  domain_name   = "${local.monitoring_subdomain}.${local.ddc_subdomain}.${var.route53_public_hosted_zone_name}"
  validation_method = "DNS"

  tags = local.tags
  lifecycle {
    create_before_destroy = true
  }
}

##########################################
# Certificate Validation Records
##########################################
# Monitoring certificate validation
resource "aws_route53_record" "monitoring_cert" {
  for_each = {
    for dvo in aws_acm_certificate.monitoring.domain_validation_options : dvo.domain_name => {
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

##########################################
# Certificate Validation
##########################################
resource "aws_acm_certificate_validation" "monitoring" {
  provider        = aws.primary
  certificate_arn = aws_acm_certificate.monitoring.arn
  validation_record_fqdns = [for record in aws_route53_record.monitoring_cert : record.fqdn]

  timeouts {
    create = "15m"
  }
}