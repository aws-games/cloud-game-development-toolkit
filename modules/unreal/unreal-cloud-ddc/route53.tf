########################################
# DNS Configuration
########################################

# Data source for public hosted zone (if provided)
data "aws_route53_zone" "public" {
  count        = var.route53_public_hosted_zone_name != null ? 1 : 0
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

########################################
# Private Hosted Zone (Primary Region)
########################################
resource "aws_route53_zone" "ddc_private_hosted_zone" {
  count = local.create_dns_resources ? 1 : 0
  name  = local.private_hosted_zone_name
  
  vpc {
    vpc_id = var.vpc_ids.primary
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-ddc-private-zone"
  })
}

# Secondary region VPC association (if multi-region)
resource "aws_route53_zone_association" "ddc_private_hosted_zone_secondary" {
  count   = local.create_dns_resources && local.is_multi_region ? 1 : 0
  zone_id = aws_route53_zone.ddc_private_hosted_zone[0].zone_id
  vpc_id  = var.vpc_ids.secondary
}

########################################
# Internal DNS Records
########################################

# Wildcard record for all DDC services (*.ddc.example.com -> Load Balancer)
# This handles monitoring.ddc.example.com, cache.ddc.example.com, etc.
resource "aws_route53_record" "internal_ddc_services" {
  count   = local.create_dns_resources ? 1 : 0
  zone_id = aws_route53_zone.ddc_private_hosted_zone[0].id
  name    = "*.${aws_route53_zone.ddc_private_hosted_zone[0].name}"
  type    = "A"
  
  alias {
    name                   = module.infrastructure_primary.scylla_monitoring_alb_dns_name
    zone_id                = module.infrastructure_primary.scylla_monitoring_alb_zone_id
    evaluate_target_health = true
  }
}

# Root DDC record (ddc.example.com -> Primary DDC endpoint)
resource "aws_route53_record" "internal_ddc_root" {
  count   = local.create_dns_resources ? 1 : 0
  zone_id = aws_route53_zone.ddc_private_hosted_zone[0].zone_id
  name    = aws_route53_zone.ddc_private_hosted_zone[0].name
  type    = "A"
  
  alias {
    name                   = module.infrastructure_primary.scylla_monitoring_alb_dns_name
    zone_id                = module.infrastructure_primary.scylla_monitoring_alb_zone_id
    evaluate_target_health = true
  }
}

########################################
# Public DNS Records (Optional)
########################################

# Public record for DDC service (ddc.example.com)
resource "aws_route53_record" "public_ddc" {
  count   = var.route53_public_hosted_zone_name != null ? 1 : 0
  zone_id = data.aws_route53_zone.public[0].id
  name    = "${var.ddc_subdomain}.${data.aws_route53_zone.public[0].name}"
  type    = "A"
  
  alias {
    name                   = module.infrastructure_primary.scylla_monitoring_alb_dns_name
    zone_id                = module.infrastructure_primary.scylla_monitoring_alb_zone_id
    evaluate_target_health = false
  }
}

# Public monitoring record (monitoring.ddc.example.com)
resource "aws_route53_record" "public_monitoring" {
  count   = var.route53_public_hosted_zone_name != null ? 1 : 0
  zone_id = data.aws_route53_zone.public[0].id
  name    = "monitoring.${var.ddc_subdomain}.${data.aws_route53_zone.public[0].name}"
  type    = "A"
  
  alias {
    name                   = module.infrastructure_primary.scylla_monitoring_alb_dns_name
    zone_id                = module.infrastructure_primary.scylla_monitoring_alb_zone_id
    evaluate_target_health = false
  }
}

# Public cache record (cache.ddc.example.com) - for DDC cache service
resource "aws_route53_record" "public_cache" {
  count   = var.route53_public_hosted_zone_name != null ? 1 : 0
  zone_id = data.aws_route53_zone.public[0].id
  name    = "cache.${var.ddc_subdomain}.${data.aws_route53_zone.public[0].name}"
  type    = "A"
  
  alias {
    name                   = module.infrastructure_primary.scylla_monitoring_alb_dns_name
    zone_id                = module.infrastructure_primary.scylla_monitoring_alb_zone_id
    evaluate_target_health = false
  }
}