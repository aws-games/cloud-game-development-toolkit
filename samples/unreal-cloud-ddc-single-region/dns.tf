variable "root_domain_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created."
}

##########################################
# Route53 Hosted Zone for Root
##########################################
data "aws_route53_zone" "root" {
  name         = var.root_domain_name
  private_zone = false
}

data "aws_lb" "unreal_cloud_ddc_load_balancer" {
  depends_on = [module.unreal_cloud_ddc_infra, module.unreal_cloud_ddc_intra_cluster]
  name       = "cgd-unreal-cloud-ddc"
}

# Create a record in the Hosted Zone for the scylla_monitoring server
resource "aws_route53_record" "unreal_cloud_ddc" {
  zone_id = data.aws_route53_zone.root.id
  name    = "ddc.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.unreal_cloud_ddc_load_balancer.dns_name
    zone_id                = data.aws_lb.unreal_cloud_ddc_load_balancer.zone_id
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
    name                   = module.unreal_cloud_ddc_infra.external_alb_dns_name
    zone_id                = module.unreal_cloud_ddc_infra.external_alb_zone_id
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
