##########################################
# DDC DNS Strategy Implementation
##########################################

# Private hosted zone for internal DNS (always created)
resource "aws_route53_zone" "private" {
  name = local.private_zone_name
  
  vpc {
    vpc_id = var.existing_vpc_id
  }
  
  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-private-zone"
    Type   = "Private Hosted Zone"
    Access = var.internet_facing ? "Internet-facing" : "Internal"
    Region = var.region
  })
}

# Additional VPC associations for cross-region access
resource "aws_route53_zone_association" "additional_vpcs" {
  for_each = var.additional_vpc_associations
  
  zone_id = aws_route53_zone.private.zone_id
  vpc_id  = each.value.vpc_id
}

# Private DNS - Regional endpoint pattern: {region}.{service}.{domain}
resource "aws_route53_record" "service_private" {
  count   = var.create_private_dns_records ? 1 : 0
  zone_id = aws_route53_zone.private.zone_id
  name    = "${local.region}.${local.service_name}.${local.private_zone_name}"
  type    = "A"
  
  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = true
  }
}

# ScyllaDB DNS records for internal service discovery
resource "aws_route53_record" "scylla_cluster" {
  count   = var.ddc_infra_config != null ? 1 : 0
  zone_id = aws_route53_zone.private.zone_id
  name    = "scylla.${local.private_zone_name}"
  type    = "A"
  ttl     = 300
  records = var.ddc_infra_config != null ? module.ddc_infra[0].scylla_ips : []
}

# Individual ScyllaDB node records for debugging
resource "aws_route53_record" "scylla_nodes" {
  count   = var.ddc_infra_config != null ? length(module.ddc_infra[0].scylla_ips) : 0
  zone_id = aws_route53_zone.private.zone_id
  name    = "scylla-${count.index + 1}.${local.private_zone_name}"
  type    = "A"
  ttl     = 300
  records = [var.ddc_infra_config != null ? module.ddc_infra[0].scylla_ips[count.index] : ""]
}

##########################################
# Public DNS Records (Example Level)
##########################################

# Public DNS records are created at the example level per design standards
# Examples create:
# - ACM certificates for HTTPS
# - Public Route53 records pointing to NLB
# - Regional endpoint pattern: us-east-1.ddc.company.com
#
# See examples/complete/dns.tf for implementation