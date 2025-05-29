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

###################################################
# Route53 Hosted Zone for Unreal DDC in US-WEST-2
###################################################

data "aws_lb" "unreal_cloud_ddc_load_balancer_us_west_2" {
  depends_on = [module.unreal_cloud_ddc_infra_us_west_2, module.unreal_cloud_ddc_intra_cluster_us_west_2]
  name       = "cgd-unreal-cloud-ddc"
}

# Create a record in the Hosted Zone for the scylla_monitoring server
resource "aws_route53_record" "unreal_cloud_ddc_vpc_us_west_2" {
  zone_id = data.aws_route53_zone.root.id
  name    = "ddc.${data.aws_region.us_west_2.region}.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.unreal_cloud_ddc_load_balancer_us_west_2.dns_name
    zone_id                = data.aws_lb.unreal_cloud_ddc_load_balancer_us_west_2.zone_id
    evaluate_target_health = false
  }
}

###################################################
# Route53 Hosted Zone for Monitoring in US-WEST-2
###################################################

# Create a record in the Hosted Zone for the scylla_monitoring server
resource "aws_route53_record" "scylla_monitoring_us_west_2" {
  zone_id = data.aws_route53_zone.root.id
  name    = "monitoring.ddc.${data.aws_region.us_west_2.region}.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unreal_cloud_ddc_infra_us_west_2.external_alb_dns_name
    zone_id                = module.unreal_cloud_ddc_infra_us_west_2.external_alb_zone_id
    evaluate_target_health = false
  }
}

# Create a certificate for the scylla_monitoring server
resource "aws_acm_certificate" "scylla_monitoring_us_west_2" {
  domain_name       = "monitoring.ddc.${data.aws_region.us_west_2.region}.${data.aws_route53_zone.root.name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "scylla_monitoring_cert_us_west_2" {
  for_each = {
    for dvo in aws_acm_certificate.scylla_monitoring_us_west_2.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "scylla_monitoring_us_west_2" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.scylla_monitoring_us_west_2.arn
  validation_record_fqdns = [for record in aws_route53_record.scylla_monitoring_cert_us_west_2 : record.fqdn]
}

###################################################
# Route53 Hosted Zone for Unreal DDC in US-EAST-2
###################################################

data "aws_lb" "unreal_cloud_ddc_load_balancer_us_east_2" {
  depends_on = [module.unreal_cloud_ddc_infra_us_east_2, module.unreal_cloud_ddc_intra_cluster_us_east_2]
  name       = "cgd-unreal-cloud-ddc"
}

# Create a record in the Hosted Zone for the scylla_monitoring server
resource "aws_route53_record" "unreal_cloud_ddc_vpc_us_east_2" {
  zone_id = data.aws_route53_zone.root.id
  name    = "ddc.${data.aws_region.us_east_2.region}.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.unreal_cloud_ddc_load_balancer_us_east_2.dns_name
    zone_id                = data.aws_lb.unreal_cloud_ddc_load_balancer_us_east_2.zone_id
    evaluate_target_health = false
  }
}

###################################################
# Route53 Hosted Zone for Monitoring in US-EAST-2
###################################################

# Create a record in the Hosted Zone for the scylla_monitoring server
resource "aws_route53_record" "scylla_monitoring_us_east_2" {
  zone_id = data.aws_route53_zone.root.id
  name    = "monitoring.ddc.${data.aws_region.us_east_2.region}.${data.aws_route53_zone.root.name}"
  type    = "A"

  alias {
    name                   = module.unreal_cloud_ddc_infra_us_east_2.external_alb_dns_name
    zone_id                = module.unreal_cloud_ddc_infra_us_east_2.external_alb_zone_id
    evaluate_target_health = false
  }
}

# Create a certificate for the scylla_monitoring server
resource "aws_acm_certificate" "scylla_monitoring_us_east_2" {
  domain_name       = "monitoring.ddc.${data.aws_region.us_east_2.region}.${data.aws_route53_zone.root.name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "scylla_monitoring_cert_us_east_2" {
  for_each = {
    for dvo in aws_acm_certificate.scylla_monitoring_us_east_2.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "scylla_monitoring_us_east_2" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.scylla_monitoring_us_east_2.arn
  validation_record_fqdns = [for record in aws_route53_record.scylla_monitoring_cert_us_east_2 : record.fqdn]
}
