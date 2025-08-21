# Creates DNS records for VDI instances if domain_name is provided

# Data source to get existing hosted zone (if it exists)
data "aws_route53_zone" "main" {
  count = var.domain_name != null ? 1 : 0
  name  = var.domain_name
}

# Create DNS records for VDI instances (if domain_name provided and instances have public IPs)
resource "aws_route53_record" "vdi_dns" {
  for_each = var.domain_name != null ? module.vdi.instance_ids : {} # VDI instances always have public IPs

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "vdi-${lower(each.key)}.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [module.vdi.public_ips[each.key]]

  depends_on = [module.vdi]
}
