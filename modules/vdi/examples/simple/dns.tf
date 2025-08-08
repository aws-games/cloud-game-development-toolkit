# Simple DNS Configuration for VDI Access
# Optional: Only created if domain_name is provided

##########################################
# Optional DNS Record for Easy Access
##########################################

# Use existing hosted zone (if domain_name is provided)
data "aws_route53_zone" "existing_zone" {
  count        = var.domain_name != null ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

# Simple DNS record for VDI access (optional)
resource "aws_route53_record" "vdi_access" {
  count   = var.domain_name != null && var.associate_public_ip_address ? 1 : 0
  zone_id = data.aws_route53_zone.existing_zone[0].zone_id
  name    = "vdi.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [module.vdi.vdi_instance_public_ip]

  depends_on = [module.vdi]
}
