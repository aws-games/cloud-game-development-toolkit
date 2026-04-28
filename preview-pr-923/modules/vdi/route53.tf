resource "aws_route53_zone" "private" {
  name = local.private_zone_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-private-zone"
    Type   = "Private Hosted Zone"
    Access = "Internal"
  })
}

resource "aws_route53_record" "user_dns_records" {
  for_each = var.create_client_vpn ? var.workstations : {}

  zone_id = aws_route53_zone.private.zone_id
  name    = "${each.value.assigned_user}.${var.project_prefix}.vdi.internal"
  type    = "A"
  ttl     = 300
  records = [aws_instance.workstations[each.key].private_ip]
}
