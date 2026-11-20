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
  name           = local.ddc_dns_name
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
  name           = local.ddc_dns_name
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

# Stable per-region name. The peer region's replicator connects to this.
resource "aws_route53_record" "unreal_cloud_ddc_regional_1" {
  zone_id = data.aws_route53_zone.root.id
  name    = local.ddc_region_hostnames[0]
  type    = "A"

  alias {
    name                   = module.unreal_cloud_ddc_intra_cluster_region_1.unreal_cloud_ddc_load_balancer_name
    zone_id                = module.unreal_cloud_ddc_intra_cluster_region_1.unreal_cloud_ddc_load_balancer_zone_id
    evaluate_target_health = false
  }
}

# Stable per-region name. The peer region's replicator connects to this.
resource "aws_route53_record" "unreal_cloud_ddc_regional_2" {
  zone_id = data.aws_route53_zone.root.id
  name    = local.ddc_region_hostnames[1]
  type    = "A"

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
  name    = "monitoring.${local.ddc_dns_name}"
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
  domain_name       = "monitoring.${local.ddc_dns_name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }
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

##########################################
# TLS certificates for the DDC NLBs
##########################################

# One certificate per region, for its regional name and the shared client name.
resource "aws_acm_certificate" "unreal_cloud_ddc_region_1" {
  region                    = var.regions[0]
  domain_name               = local.ddc_region_hostnames[0]
  subject_alternative_names = [local.ddc_dns_name]
  validation_method         = "DNS"
  tags                      = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "unreal_cloud_ddc_region_2" {
  region                    = var.regions[1]
  domain_name               = local.ddc_region_hostnames[1]
  subject_alternative_names = [local.ddc_dns_name]
  validation_method         = "DNS"
  tags                      = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Both certificates share the client name, and ACM gives a domain the same
# validation record in every region, so the records are de-duplicated by domain
# (keys must be known at plan time).
resource "aws_route53_record" "unreal_cloud_ddc_cert_validation" {
  for_each = toset(concat(local.ddc_region_hostnames, [local.ddc_dns_name]))

  allow_overwrite = true
  zone_id         = data.aws_route53_zone.root.id
  name            = local.ddc_cert_validation[each.key][0].resource_record_name
  type            = local.ddc_cert_validation[each.key][0].resource_record_type
  records         = [local.ddc_cert_validation[each.key][0].resource_record_value]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "unreal_cloud_ddc_region_1" {
  region                  = var.regions[0]
  certificate_arn         = aws_acm_certificate.unreal_cloud_ddc_region_1.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.unreal_cloud_ddc_region_1.domain_validation_options : dvo.resource_record_name]
  depends_on              = [aws_route53_record.unreal_cloud_ddc_cert_validation]
  timeouts {
    create = "15m"
  }
}

resource "aws_acm_certificate_validation" "unreal_cloud_ddc_region_2" {
  region                  = var.regions[1]
  certificate_arn         = aws_acm_certificate.unreal_cloud_ddc_region_2.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.unreal_cloud_ddc_region_2.domain_validation_options : dvo.resource_record_name]
  depends_on              = [aws_route53_record.unreal_cloud_ddc_cert_validation]
  timeouts {
    create = "15m"
  }
}

locals {
  # Validation record per domain, from whichever certificate covers it.
  ddc_cert_validation = {
    for dvo in concat(
      tolist(aws_acm_certificate.unreal_cloud_ddc_region_1.domain_validation_options),
      tolist(aws_acm_certificate.unreal_cloud_ddc_region_2.domain_validation_options)
    ) : dvo.domain_name => dvo...
  }
}
