##########################################
# DDC Internal (Private) DNS
##########################################
# Create new private hosted zone (primary region)
resource "aws_route53_zone" "ddc_private_hosted_zone" {
  count = var.create_route53_private_hosted_zone && var.shared_private_zone_id == null ? 1 : 0
  name  = local.private_hosted_zone_name
  
  #checkov:skip=CKV2_AWS_38: Hosted zone is private (vpc association)
  #checkov:skip=CKV2_AWS_39: Query logging disabled by design
  vpc {
    vpc_id = var.vpc_id
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-ddc-private-zone"
  })
}

# Associate VPC with existing private hosted zone (secondary regions)
resource "aws_route53_zone_association" "ddc_private_secondary" {
  count      = var.shared_private_zone_id != null ? 1 : 0
  zone_id    = var.shared_private_zone_id
  vpc_id     = var.vpc_id
  vpc_region = var.region
}

# Route all internal DDC service traffic to the DDC NLB
resource "aws_route53_record" "internal_ddc_root" {
  count   = var.create_route53_private_hosted_zone && var.ddc_infra_config != null ? 1 : 0
  zone_id = aws_route53_zone.ddc_private_hosted_zone[0].zone_id
  name    = aws_route53_zone.ddc_private_hosted_zone[0].name
  type    = "A"
  
  alias {
    name                   = module.ddc_infra[0].nlb_dns_name
    zone_id                = module.ddc_infra[0].nlb_zone_id
    evaluate_target_health = true
  }
}

# Route all internal monitoring traffic to the monitoring ALB
resource "aws_route53_record" "internal_ddc_monitoring" {
  count   = var.create_route53_private_hosted_zone && var.ddc_monitoring_config != null && var.ddc_monitoring_config.create_application_load_balancer ? 1 : 0
  zone_id = aws_route53_zone.ddc_private_hosted_zone[0].id
  name    = "*.${aws_route53_zone.ddc_private_hosted_zone[0].name}"
  type    = "A"
  
  alias {
    name                   = module.ddc_monitoring[0].scylla_monitoring_alb_dns_name
    zone_id                = module.ddc_monitoring[0].scylla_monitoring_alb_zone_id
    evaluate_target_health = true
  }
}