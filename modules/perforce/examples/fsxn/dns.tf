##########################################
# Route53 Hosted Zone for FQDN
##########################################
data "aws_route53_zone" "root" {
  name         = var.root_domain_name
  private_zone = false
}

# Route all external Helix Core traffic to P4 Server
resource "aws_route53_record" "external_helix_core" {
  #checkov:skip=CKV2_AWS_23: Route53 Record associated with P4 Server EIP
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "perforce.${data.aws_route53_zone.root.name}"
  type    = "A"
  records = [module.perforce_helix_core.helix_core_eip_public_ip]
}
