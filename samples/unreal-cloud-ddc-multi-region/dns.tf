##########################################
# Route53 Hosted Zone for Root
##########################################
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

# Create a record in the Hosted Zone for the unreal cloud ddc in region 1
resource "aws_route53_record" "unreal_cloud_ddc_region_1" {
  depends_on     = [module.unreal_cloud_ddc_infra_region_1, module.unreal_cloud_ddc_intra_cluster_region_1]
  zone_id        = data.aws_route53_zone.root.id
  name           = "ddc.${data.aws_route53_zone.root.name}"
  type           = "A"
  set_identifier = var.regions[0]

  latency_routing_policy {
    region = var.regions[0]
  }
  alias {
    name                   = module.unreal_cloud_ddc_intra_cluster_region_1.unreal_cloud_ddc_load_balancer_name
    zone_id                = module.unreal_cloud_ddc_intra_cluster_region_1.unreal_cloud_ddc_load_balancer_zone_id
    evaluate_target_health = false
  }
}

# Create a record in the Hosted Zone for the unreal cloud ddc in region 2
resource "aws_route53_record" "unreal_cloud_ddc_region_2" {
  depends_on     = [module.unreal_cloud_ddc_infra_region_2, module.unreal_cloud_ddc_intra_cluster_region_2]
  zone_id        = data.aws_route53_zone.root.id
  name           = "ddc.${data.aws_route53_zone.root.name}"
  type           = "A"
  set_identifier = var.regions[1]

  latency_routing_policy {
    region = var.regions[1]
  }

  alias {
    name                   = module.unreal_cloud_ddc_intra_cluster_region_2.unreal_cloud_ddc_load_balancer_name
    zone_id                = module.unreal_cloud_ddc_intra_cluster_region_2.unreal_cloud_ddc_load_balancer_zone_id
    evaluate_target_health = false
  }
}

##########################################
# Route53 Hosted Zone for Monitoring
##########################################

# Create a record in the Hosted Zone for the scylla_monitoring server
resource "aws_route53_record" "scylla_monitoring_region_1" {
  zone_id = data.aws_route53_zone.root.id
  name    = "${var.regions[0]}.monitoring.ddc.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unreal_cloud_ddc_infra_region_1.external_alb_dns_name
    zone_id                = module.unreal_cloud_ddc_infra_region_1.external_alb_zone_id
    evaluate_target_health = false
  }
}

# Create a certificate for the scylla_monitoring server
resource "aws_acm_certificate" "scylla_monitoring_region_1" {
  region            = var.regions[0]
  domain_name       = "*.ddc.${data.aws_route53_zone.root.name}"
  subject_alternative_names = [
    "*.monitoring.ddc.${data.aws_route53_zone.root.name}"
  ]
  validation_method = "DNS"

  tags = local.tags
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "scylla_monitoring_cert_region_1" {
  for_each = {
    for dvo in aws_acm_certificate.scylla_monitoring_region_1.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "scylla_monitoring_region_1" {
  region = var.regions[0]
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.scylla_monitoring_region_1.arn
  validation_record_fqdns = [for record in aws_route53_record.scylla_monitoring_cert_region_1 : record.fqdn]
}
