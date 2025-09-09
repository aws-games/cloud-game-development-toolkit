# DNS Architecture for VDI Module

# Service private zone (CGD pattern)
resource "aws_route53_zone" "vdi_service" {
  count = var.dns_config != null && var.dns_config.private_zone.enabled ? 1 : 0
  
  name = var.dns_config.private_zone.domain_name
  
  vpc {
    vpc_id = var.dns_config.private_zone.vpc_id != null ? var.dns_config.private_zone.vpc_id : var.vpc_id
  }
  
  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-vdi-service-zone"
    Purpose = "VDI Service DNS"
    Type    = "Private"
  })
}

# VDI instance DNS records
resource "aws_route53_record" "vdi_instances" {
  for_each = var.dns_config != null && var.dns_config.private_zone.enabled ? local.processed_assignments : {}
  
  zone_id = aws_route53_zone.vdi_service[0].zone_id
  name    = "${each.key}.${var.dns_config.private_zone.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.workstations[each.key].private_ip]
}

# Regional endpoint records (if enabled)
resource "aws_route53_record" "regional_endpoints" {
  for_each = var.dns_config != null && var.dns_config.regional_endpoints.enabled ? local.processed_assignments : {}
  
  zone_id = aws_route53_zone.vdi_service[0].zone_id
  name = replace(replace(var.dns_config.regional_endpoints.pattern, "{region}", data.aws_region.current.id), "{domain}", var.dns_config.private_zone.domain_name)
  type = "A"
  ttl  = 300
  records = [aws_instance.workstations[each.key].private_ip]
}

# Load balancer alias (if enabled and ALB exists)
resource "aws_route53_record" "load_balancer_alias" {
  count = var.dns_config != null && var.dns_config.load_balancer_alias.enabled ? 1 : 0
  
  zone_id = aws_route53_zone.vdi_service[0].zone_id
  name    = "${var.dns_config.load_balancer_alias.subdomain}.${var.dns_config.private_zone.domain_name}"
  type    = "A"
  
  # This would reference an ALB if one existed
  # For now, just create a placeholder
  ttl     = 300
  records = ["10.0.0.1"]  # Placeholder
}

# DNS outputs for connection information
locals {
  dns_endpoints = var.dns_config != null && var.dns_config.private_zone.enabled ? {
    for assignment_key, config in local.processed_assignments : assignment_key => {
      fqdn = "${assignment_key}.${var.dns_config.private_zone.domain_name}"
      dcv_url = "https://${assignment_key}.${var.dns_config.private_zone.domain_name}:8443"
      rdp_endpoint = "${assignment_key}.${var.dns_config.private_zone.domain_name}:3389"
    }
  } : {}
}