##########################################
# Route53 Hosted Zone for FQDN
##########################################
data "aws_route53_zone" "root" {
  name         = var.root_domain_name
  private_zone = false
}
