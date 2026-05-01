##########################################
# Fetch Shared NLB DNS Name and Zone ID
##########################################
data "aws_lb" "shared_services_nlb" {
  arn = module.terraform-aws-perforce.shared_network_load_balancer_arn

  depends_on = [module.terraform-aws-perforce]
}

##########################################
# Fetch Route53 Public Hosted Zone for FQDN
##########################################
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

##########################################
# Perforce External (Public) DNS
##########################################
# Route all external web service traffic (e.g. auth.perforce.example.com, review.perforce.example.com) to the Public NLB
resource "aws_route53_record" "external_perforce_web_services" {
  zone_id = data.aws_route53_zone.root.id
  name    = "*.${local.p4_server_fully_qualified_domain_name}"
  type    = "A"
  alias {
    name                   = data.aws_lb.shared_services_nlb.dns_name
    zone_id                = data.aws_lb.shared_services_nlb.zone_id
    evaluate_target_health = true
  }
}

# Route external web service traffic to the public EIP of the P4 Server
resource "aws_route53_record" "external_perforce_p4_server" {
  #checkov:skip=CKV2_AWS_23: Attached to EIP public IP
  zone_id = data.aws_route53_zone.root.id
  name    = "perforce.${data.aws_route53_zone.root.name}"
  type    = "A"
  ttl     = 300
  records = [module.terraform-aws-perforce.p4_server_eip_public_ip]
}


##########################################
# P4 Code Review Certificate Management
##########################################
resource "aws_acm_certificate" "perforce" {
  domain_name = "*.${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"

  validation_method = "DNS"

  #checkov:skip=CKV2_AWS_71: Wildcard is necessary for this domain

  tags = {
    environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "perforce_cert" {
  for_each = {
    for dvo in aws_acm_certificate.perforce.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.root.id
}

resource "aws_acm_certificate_validation" "perforce" {
  certificate_arn         = aws_acm_certificate.perforce.arn
  validation_record_fqdns = [for record in aws_route53_record.perforce_cert : record.fqdn]


  lifecycle {
    create_before_destroy = true
  }
  timeouts {
    create = "15m"
  }
}
