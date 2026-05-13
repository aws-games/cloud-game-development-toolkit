##########################################
# Route53 Hosted Zone for FQDN
##########################################
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

# Route all external Helix Core traffic to P4 Server
resource "aws_route53_record" "external_p4_server" {
  #checkov:skip=CKV2_AWS_23: Route53 Record associated with P4 Server EIP
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "perforce.${data.aws_route53_zone.root.name}"
  type    = "A"
  ttl     = 300
  records = [module.perforce.p4_server_eip_public_ip]
}
