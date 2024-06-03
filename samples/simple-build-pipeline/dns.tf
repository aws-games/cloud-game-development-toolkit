# private hosted zone for internal DNS resolution
resource "aws_route53_zone" "perforce_private_zone" {
  name = "perforce.internal"
  vpc {
    vpc_id = aws_vpc.build_pipeline_vpc.id
  }
}

resource "aws_route53_record" "perforce_helix_core" {
  zone_id = aws_route53_zone.perforce_private_zone.zone_id
  name    = "core.${aws_route53_zone.perforce_private_zone.name}"
  type    = "A"
  ttl     = 300
  records = [module.perforce_helix_core.helix_core_eip_private_ip]
}


resource "aws_route53_record" "helix_authentication_service" {
  zone_id = aws_route53_zone.perforce_private_zone.zone_id
  name    = "auth.${aws_route53_zone.perforce_private_zone.name}"
  type    = "A"
  alias {
    name                   = module.perforce_helix_authentication_service.alb_dns_name
    zone_id                = module.perforce_helix_authentication_service.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "helix_swarm" {
  zone_id = aws_route53_zone.perforce_private_zone.zone_id
  name    = "swarm.${aws_route53_zone.perforce_private_zone.name}"
  type    = "A"
  alias {
    name                   = module.perforce_helix_swarm.alb_dns_name
    zone_id                = module.perforce_helix_swarm.alb_zone_id
    evaluate_target_health = true
  }
}
