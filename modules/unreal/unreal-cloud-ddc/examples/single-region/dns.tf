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
  name       = "ddc.${data.aws_route53_zone.root.name}"
  type       = "A"

  alias {
    name                   = module.unreal_cloud_ddc.ddc_endpoints.primary.load_balancer_dns
    zone_id                = module.unreal_cloud_ddc.primary_region.vpc_id  # This needs to be fixed to actual zone_id
    evaluate_target_health = false
  }
}

##########################################
# Route53 Hosted Zone for Monitoring
##########################################

# Create a record in the Hosted Zone for the scylla_monitoring server
resource "aws_route53_record" "scylla_monitoring" {
  zone_id = data.aws_route53_zone.root.id
  name    = "monitoring.ddc.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = "example.com"  # TODO: Fix with actual ALB DNS from unified module
    zone_id                = "Z123456789"   # TODO: Fix with actual ALB zone ID
    evaluate_target_health = false
  }
}

# Create a certificate for the scylla_monitoring server
resource "aws_acm_certificate" "scylla_monitoring" {
  domain_name       = "monitoring.ddc.${data.aws_route53_zone.root.name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }
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
