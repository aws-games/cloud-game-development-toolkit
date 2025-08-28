# Route53 Hosted Zone
data "aws_route53_zone" "root" {
  provider     = aws.primary
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

# Primary region DDC record
resource "aws_route53_record" "unreal_cloud_ddc_primary" {
  provider = aws.primary
  
  zone_id = data.aws_route53_zone.root.id
  name    = "ddc-primary.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unreal_cloud_ddc.primary_region.ddc_endpoints.load_balancer_dns
    zone_id                = module.unreal_cloud_ddc.primary_region.ddc_endpoints.load_balancer_zone_id
    evaluate_target_health = false
  }
}

# Secondary region DDC record
resource "aws_route53_record" "unreal_cloud_ddc_secondary" {
  provider = aws.primary
  
  zone_id = data.aws_route53_zone.root.id
  name    = "ddc-secondary.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unreal_cloud_ddc.secondary_region.ddc_endpoints.load_balancer_dns
    zone_id                = module.unreal_cloud_ddc.secondary_region.ddc_endpoints.load_balancer_zone_id
    evaluate_target_health = false
  }
}

# Primary region monitoring record
resource "aws_route53_record" "scylla_monitoring_primary" {
  provider = aws.primary
  
  zone_id = data.aws_route53_zone.root.id
  name    = "monitoring-primary.ddc.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unreal_cloud_ddc.primary_region.monitoring_load_balancer_dns
    zone_id                = module.unreal_cloud_ddc.primary_region.monitoring_load_balancer_zone_id
    evaluate_target_health = false
  }
}

# Secondary region monitoring record
resource "aws_route53_record" "scylla_monitoring_secondary" {
  provider = aws.primary
  
  zone_id = data.aws_route53_zone.root.id
  name    = "monitoring-secondary.ddc.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unreal_cloud_ddc.secondary_region.monitoring_load_balancer_dns
    zone_id                = module.unreal_cloud_ddc.secondary_region.monitoring_load_balancer_zone_id
    evaluate_target_health = false
  }
}

# ACM Certificate for primary region monitoring
resource "aws_acm_certificate" "scylla_monitoring_primary" {
  provider = aws.primary
  
  domain_name       = "monitoring-primary.ddc.${data.aws_route53_zone.root.name}"
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-monitoring-primary-cert"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# ACM Certificate for secondary region monitoring
resource "aws_acm_certificate" "scylla_monitoring_secondary" {
  provider = aws.secondary
  
  domain_name       = "monitoring-secondary.ddc.${data.aws_route53_zone.root.name}"
  validation_method = "DNS"

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-monitoring-secondary-cert"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# Certificate validation records
resource "aws_route53_record" "scylla_monitoring_cert_primary" {
  provider = aws.primary
  
  for_each = {
    for dvo in aws_acm_certificate.scylla_monitoring_primary.domain_validation_options : dvo.domain_name => {
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

resource "aws_route53_record" "scylla_monitoring_cert_secondary" {
  provider = aws.primary
  
  for_each = {
    for dvo in aws_acm_certificate.scylla_monitoring_secondary.domain_validation_options : dvo.domain_name => {
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

# Certificate validation
resource "aws_acm_certificate_validation" "scylla_monitoring_primary" {
  provider = aws.primary
  
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.scylla_monitoring_primary.arn
  validation_record_fqdns = [for record in aws_route53_record.scylla_monitoring_cert_primary : record.fqdn]
}

resource "aws_acm_certificate_validation" "scylla_monitoring_secondary" {
  provider = aws.secondary
  
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.scylla_monitoring_secondary.arn
  validation_record_fqdns = [for record in aws_route53_record.scylla_monitoring_cert_secondary : record.fqdn]
}