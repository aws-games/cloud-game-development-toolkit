##########################################
# DDC DNS Strategy Implementation
##########################################

# Private hosted zone for internal DNS (only created in primary region)
resource "aws_route53_zone" "private" {
  count = var.is_primary_region ? 1 : 0
  
  name = local.service_domain
  # CRITICAL: External-DNS EKS Addon creates records (A, AAAA, TXT) that can't be cleaned up when EKS cluster is destroyed
  # because the External-DNS addon terminates with the cluster. force_destroy automatically deletes all
  # records before zone deletion, preventing "HostedZoneNotEmpty" errors during terraform destroy.
  # there is also a cleanup script in place to handle this as well (cleanup.tf)
  force_destroy = true

  vpc {
    vpc_id     = var.vpc_id
    vpc_region = local.region
  }

  tags = merge(local.default_tags, {
    Name   = "${local.name_prefix}-private-zone"
    Type   = "Private Hosted Zone"
    Access = var.load_balancers_config.nlb != null ? (var.load_balancers_config.nlb.internet_facing ? "Internet-facing" : "Internal") : "Internal"
  })
}

# Additional VPC associations for cross-region access
resource "aws_route53_zone_association" "additional_vpcs" {
  for_each = var.is_primary_region && var.additional_vpc_associations != null ? var.additional_vpc_associations : {}

  zone_id = aws_route53_zone.private[0].zone_id
  vpc_id  = each.value.vpc_id
}

# Private DNS - Regional service endpoint created by External-DNS
# External-DNS automatically creates ALIAS records for LoadBalancer services
# No manual Route53 records needed

# ScyllaDB DNS records for internal service discovery
resource "aws_route53_record" "scylla_cluster" {
  count   = var.is_primary_region && var.ddc_infra_config != null && local.database_type == "scylla" && length(module.ddc_infra.scylla_ips) > 0 ? 1 : 0
  zone_id = aws_route53_zone.private[0].zone_id
  name    = "scylla.${local.service_domain}"
  type    = "A"
  ttl     = 300
  records = module.ddc_infra.scylla_ips
}

# Individual ScyllaDB node records for debugging
resource "aws_route53_record" "scylla_nodes" {
  count   = var.is_primary_region && var.ddc_infra_config != null && local.database_type == "scylla" ? length(module.ddc_infra.scylla_ips) : 0
  zone_id = aws_route53_zone.private[0].zone_id
  name    = "scylla-${count.index + 1}.${local.service_domain}"
  type    = "A"
  ttl     = 300
  records = [module.ddc_infra.scylla_ips[count.index]]
}
