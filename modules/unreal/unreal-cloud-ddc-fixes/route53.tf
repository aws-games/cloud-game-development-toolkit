##########################################
# DDC DNS Strategy Implementation
##########################################

# Private hosted zone for internal DNS (always created)
resource "aws_route53_zone" "private" {
  name = local.private_zone_name
  
  vpc {
    vpc_id = var.vpc_id
  }
  
  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-private-zone"
    Type   = "Private Hosted Zone"
    Access = local.is_external_access ? "External" : "Internal"
    Region = var.region
  })
}

# Additional VPC associations for cross-region access
resource "aws_route53_zone_association" "additional_vpcs" {
  for_each = var.additional_vpc_associations
  
  zone_id = aws_route53_zone.private.zone_id
  vpc_id  = each.value.vpc_id
}

# Private DNS - Regional endpoint for internal service discovery
# External access: us-east-1.ddc.example.com (same as public, different zone)
# Internal access: us-east-1.ddc.internal
resource "aws_route53_record" "service_private" {
  count   = var.create_private_dns_records ? 1 : 0
  zone_id = aws_route53_zone.private.zone_id
  name    = "${var.region}.${local.private_zone_name}"
  type    = "A"
  
  alias {
    name                   = aws_lb.shared_nlb.dns_name
    zone_id                = aws_lb.shared_nlb.zone_id
    evaluate_target_health = true
  }
}

# Certificate management should be handled at example level per design standards
# Public certificates and DNS records are created in examples/complete/dns.tf