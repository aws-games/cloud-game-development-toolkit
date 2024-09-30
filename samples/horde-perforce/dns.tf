
##########################################
# Route53 Hosted Zone for Root Domain
##########################################
data "aws_route53_zone" "root" {
  name         = var.root_domain_name
  private_zone = false
}


resource "aws_route53_record" "helix_swarm" {
  zone_id = data.aws_route53_zone.root.id
  name    = "swarm.helix.${data.aws_route53_zone.root.name}"
  type    = "A"
  alias {
    name                   = module.perforce_helix_swarm.alb_dns_name
    zone_id                = module.perforce_helix_swarm.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "helix_authentication_service" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "auth.helix.${data.aws_route53_zone.root.name}"
  type    = "A"
  alias {
    name                   = module.perforce_helix_authentication_service.alb_dns_name
    zone_id                = module.perforce_helix_authentication_service.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "perforce_helix_core" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "core.helix.${data.aws_route53_zone.root.name}"
  type    = "A"
  ttl     = 300
  #checkov:skip=CKV2_AWS_23:The attached resource is managed by CGD Toolkit
  records = [module.perforce_helix_core.helix_core_eip_public_ip]
}


resource "aws_route53_record" "unreal_engine_horde" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "horde.${data.aws_route53_zone.root.name}"
  type    = "A"
  alias {
    name                   = module.unreal_engine_horde.external_alb_dns_name
    zone_id                = module.unreal_engine_horde.external_alb_zone_id
    evaluate_target_health = true
  }
}

##########################################
# Internal Hosted Zone for Perforce
##########################################

resource "aws_route53_zone" "helix_private_zone" {
  name = "helix.${var.root_domain_name}"
  #checkov:skip=CKV2_AWS_38: Hosted zone is private (vpc association)
  #checkov:skip=CKV2_AWS_39: Query logging disabled by design
  vpc {
    vpc_id = aws_vpc.build_pipeline_vpc.id
  }
}

resource "aws_route53_record" "perforce_helix_core_internal" {
  zone_id = aws_route53_zone.helix_private_zone.zone_id
  name    = "core.${aws_route53_zone.helix_private_zone.name}"
  type    = "A"
  ttl     = 300
  #checkov:skip=CKV2_AWS_23:The attached resource is managed by CGD Toolkit
  records = [module.perforce_helix_core.helix_core_eip_private_ip]
}

resource "aws_route53_record" "helix_swarm_internal" {
  zone_id = aws_route53_zone.helix_private_zone.id
  name    = "swarm.${aws_route53_zone.helix_private_zone.name}"
  type    = "A"
  alias {
    name                   = module.perforce_helix_swarm.alb_dns_name
    zone_id                = module.perforce_helix_swarm.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "helix_authentication_service_internal" {
  zone_id = aws_route53_zone.helix_private_zone.id
  name    = "auth.${aws_route53_zone.helix_private_zone.name}"
  type    = "A"
  alias {
    name                   = module.perforce_helix_authentication_service.alb_dns_name
    zone_id                = module.perforce_helix_authentication_service.alb_zone_id
    evaluate_target_health = true
  }
}

##########################################
# Internal Hosted Zone for Unreal Horde
##########################################

resource "aws_route53_zone" "unreal_engine_horde_private_zone" {
  name = "horde.${var.root_domain_name}"
  #checkov:skip=CKV2_AWS_38: Hosted zone is private (vpc association)
  #checkov:skip=CKV2_AWS_39: Query logging disabled by design
  vpc {
    vpc_id = aws_vpc.build_pipeline_vpc.id
  }
}

resource "aws_route53_record" "unreal_engine_horde_internal" {
  zone_id = aws_route53_zone.unreal_engine_horde_private_zone.zone_id
  name    = aws_route53_zone.unreal_engine_horde_private_zone.name
  type    = "A"
  alias {
    name                   = module.unreal_engine_horde.internal_alb_dns_name
    zone_id                = module.unreal_engine_horde.internal_alb_zone_id
    evaluate_target_health = true
  }
}

##########################################
# Unreal Engine Horde Certificate Management
##########################################

resource "aws_acm_certificate" "unreal_engine_horde" {
  domain_name       = "horde.${var.root_domain_name}"
  validation_method = "DNS"

  tags = {
    environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "unreal_engine_horde_cert" {
  for_each = {
    for dvo in aws_acm_certificate.unreal_engine_horde.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "unreal_engine_horde" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.unreal_engine_horde.arn
  validation_record_fqdns = [for record in aws_route53_record.unreal_engine_horde_cert : record.fqdn]
}
##########################################
# Perforce Helix Certificate Management
##########################################

resource "aws_acm_certificate" "helix" {
  domain_name               = "helix.${var.root_domain_name}"
  subject_alternative_names = ["*.helix.${var.root_domain_name}"]

  validation_method = "DNS"

  tags = {
    environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "helix_cert" {
  for_each = {
    for dvo in aws_acm_certificate.helix.domain_validation_options : dvo.domain_name => {
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

resource "aws_acm_certificate_validation" "helix" {
  timeouts {
    create = "15m"
  }
  certificate_arn         = aws_acm_certificate.helix.arn
  validation_record_fqdns = [for record in aws_route53_record.helix_cert : record.fqdn]
}
