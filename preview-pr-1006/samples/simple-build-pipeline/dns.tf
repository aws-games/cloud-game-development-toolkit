
##########################################
# Route53 DNS Records
##########################################

# Public route53 hosted zone for external DNS resolution
data "aws_route53_zone" "root" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

# Internal private hosted zone for DNS resolution
resource "aws_route53_zone" "private_zone" {
  name = var.route53_public_hosted_zone_name
  #checkov:skip=CKV2_AWS_38: Hosted zone is private (vpc association)
  #checkov:skip=CKV2_AWS_39: Query logging disabled by design
  vpc {
    vpc_id = aws_vpc.build_pipeline_vpc.id
  }
}

# Public P4 Web Services Record resolves to public NLB
resource "aws_route53_record" "p4_web_services_public" {
  zone_id = data.aws_route53_zone.root.id
  name    = "*.${local.perforce_subdomain}.${data.aws_route53_zone.root.name}"
  type    = "A"
  alias {
    name                   = aws_lb.service_nlb.dns_name
    zone_id                = aws_lb.service_nlb.zone_id
    evaluate_target_health = true
  }
}

# Public Jenkins Record resolves to public NLB
resource "aws_route53_record" "jenkins_public" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.jenkins_fully_qualified_domain_name
  type    = "A"
  alias {
    name                   = aws_lb.service_nlb.dns_name
    zone_id                = aws_lb.service_nlb.zone_id
    evaluate_target_health = true
  }
}

# Internal P4 Web Services Record resolves to internal ALB
resource "aws_route53_record" "p4_web_services_private" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "*.${local.perforce_subdomain}.${aws_route53_zone.private_zone.name}"
  type    = "A"
  #checkov:skip=CKV2_AWS_23:The attached resource is managed by CGD Toolkit
  alias {
    name                   = aws_lb.web_alb.dns_name
    zone_id                = aws_lb.web_alb.zone_id
    evaluate_target_health = true
  }
}

# Internal Jenkins Record resolves to internal ALB
resource "aws_route53_record" "jenkins_private" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = local.jenkins_fully_qualified_domain_name
  type    = "A"
  #checkov:skip=CKV2_AWS_23:The attached resource is managed by CGD Toolkit
  alias {
    name                   = aws_lb.web_alb.dns_name
    zone_id                = aws_lb.web_alb.zone_id
    evaluate_target_health = true
  }
}

# Public P4 Server Record
resource "aws_route53_record" "p4_server_public" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = local.p4_server_fully_qualified_domain_name
  type    = "A"
  ttl     = 300
  #checkov:skip=CKV2_AWS_23:The attached resource is managed by CGD Toolkit
  records = [module.terraform-aws-perforce.p4_server_eip_public_ip]
}

# Internal P4 Server Record
resource "aws_route53_record" "p4_server_private" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = local.p4_server_fully_qualified_domain_name
  type    = "A"
  ttl     = 300
  #checkov:skip=CKV2_AWS_23:The attached resource is managed by CGD Toolkit
  records = [module.terraform-aws-perforce.p4_server_private_ip]
}

##########################################
# Certificate Management
##########################################

resource "aws_acm_certificate" "shared" {
  domain_name = var.route53_public_hosted_zone_name
  subject_alternative_names = [
    local.jenkins_fully_qualified_domain_name,
    local.p4_auth_fully_qualified_domain_name,
    local.p4_code_review_fully_qualified_domain_name
  ]
  validation_method = "DNS"

  tags = {
    environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "shared_certificate" {
  for_each = {
    for dvo in aws_acm_certificate.shared.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "shared_certificate" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.shared.arn
  validation_record_fqdns = [for record in aws_route53_record.shared_certificate : record.fqdn]
}
