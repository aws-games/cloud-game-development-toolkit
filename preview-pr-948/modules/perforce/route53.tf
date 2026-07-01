##########################################
# Perforce Internal (Private) DNS
##########################################
resource "aws_route53_zone" "perforce_private_hosted_zone" {
  count = var.create_route53_private_hosted_zone != false ? 1 : 0
  name  = var.route53_private_hosted_zone_name
  #checkov:skip=CKV2_AWS_38: Hosted zone is private (vpc association)
  #checkov:skip=CKV2_AWS_39: Query logging disabled by design
  vpc {
    vpc_id = var.vpc_id
  }
}

# Route all internal web service traffic (e.g. auth.perforce.example.com, review.perforce.example.com) to the Private ALB
resource "aws_route53_record" "internal_perforce_web_services" {
  count   = var.create_shared_application_load_balancer && var.create_route53_private_hosted_zone ? 1 : 0
  zone_id = aws_route53_zone.perforce_private_hosted_zone[0].id
  name    = "*.${aws_route53_zone.perforce_private_hosted_zone[0].name}"
  type    = "A"
  alias {
    name                   = aws_lb.perforce_web_services[0].dns_name
    zone_id                = aws_lb.perforce_web_services[0].zone_id
    evaluate_target_health = true
  }
}

# Route all internal P4 Server traffic to the instance
resource "aws_route53_record" "internal_p4_server" {
  count   = var.p4_server_config != null && var.create_route53_private_hosted_zone ? 1 : 0
  zone_id = aws_route53_zone.perforce_private_hosted_zone[0].zone_id
  name    = aws_route53_zone.perforce_private_hosted_zone[0].name
  type    = "A"
  records = [module.p4_server[0].private_ip]
  ttl     = 300

  #checkov:skip=CKV2_AWS_23: Route53 A record is necessary for this example deployment
}
