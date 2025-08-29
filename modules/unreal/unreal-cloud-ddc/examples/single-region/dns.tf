##########################################
# Fetch Monitoring ALB Details
##########################################
data "aws_lb" "monitoring_alb" {
  arn = module.unreal_cloud_ddc.primary_region.scylla_monitoring_alb_arn
  depends_on = [module.unreal_cloud_ddc]
}

##########################################
# Route53 Hosted Zone for Root
##########################################
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

# Create a record in the Hosted Zone for the DDC service
resource "aws_route53_record" "unreal_cloud_ddc" {
  depends_on = [module.unreal_cloud_ddc]
  zone_id    = data.aws_route53_zone.root.id
  name       = local.ddc_fully_qualified_domain_name
  type       = "CNAME"
  ttl        = 300
  records    = [module.unreal_cloud_ddc.ddc_endpoints.primary.load_balancer_dns]
}

##########################################
# Route53 Hosted Zone for Monitoring
##########################################

# Create a record in the Hosted Zone for the scylla_monitoring server
resource "aws_route53_record" "scylla_monitoring" {
  depends_on = [module.unreal_cloud_ddc]
  zone_id    = data.aws_route53_zone.root.id
  name       = local.monitoring_fully_qualified_domain_name
  type       = "A"

  alias {
    name                   = data.aws_lb.monitoring_alb.dns_name
    zone_id                = data.aws_lb.monitoring_alb.zone_id
    evaluate_target_health = false
  }
}

# Create a certificate for the scylla_monitoring server
resource "aws_acm_certificate" "scylla_monitoring" {
  domain_name       = local.monitoring_fully_qualified_domain_name
  validation_method = "DNS"

  tags = local.tags
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "scylla_monitoring_cert" {
  for_each = {
    for dvo in aws_acm_certificate.scylla_monitoring.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "scylla_monitoring" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.scylla_monitoring.arn
  validation_record_fqdns = [for record in aws_route53_record.scylla_monitoring_cert : record.fqdn]
}
