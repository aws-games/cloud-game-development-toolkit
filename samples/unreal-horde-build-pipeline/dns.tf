##################################################
# DNS — JT-11
#
# This sample OWNS its DNS. The perforce module is deployed with
# create_route53_private_hosted_zone = false, so we create the private hosted
# zone here and associate it with the VPC. Records:
#   * private: perforce.{private_zone} -> P4 Server private IP (A)
#   * private: horde.{private_zone}    -> Horde internal ALB (ALIAS A)
#   * public:  {horde_public_fqdn}     -> Horde external ALB (ALIAS A)
#
# The public record completes the browser-facing endpoint deferred from JT-07
# (the ACM cert + validation records were created there; the ALB alias lives
# here now that the Horde module's external ALB outputs exist).
##################################################

##################################################
# Private Hosted Zone (internal service discovery)
##################################################

resource "aws_route53_zone" "private" {
  name = var.route53_private_zone_name

  vpc {
    vpc_id = aws_vpc.horde_pipeline_vpc.id
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-zone"
  })

  #checkov:skip=CKV2_AWS_38:Private hosted zone; DNSSEC not applicable
  #checkov:skip=CKV2_AWS_39:Query logging out of scope for this sample
}

# Perforce server A record -> private IP (only when this sample deploys P4).
resource "aws_route53_record" "perforce_internal" {
  count   = local.deploy_perforce ? 1 : 0
  zone_id = aws_route53_zone.private.zone_id
  name    = local.perforce_internal_fqdn
  type    = "A"
  ttl     = 300
  records = [module.perforce[0].p4_server_private_ip]
}

# Horde internal ALB ALIAS record (in-VPC agent enrollment / service traffic).
resource "aws_route53_record" "horde_internal" {
  zone_id = aws_route53_zone.private.zone_id
  name    = local.horde_internal_fqdn
  type    = "A"

  alias {
    name                   = module.horde.internal_alb_dns_name
    zone_id                = module.horde.internal_alb_zone_id
    evaluate_target_health = false
  }
}

##################################################
# Public record — Horde external ALB (completes JT-07)
#
# The ACM certificate and its DNS validation records were created in main.tf
# (JT-07) against data.aws_route53_zone.public. This ALIAS points the public
# Horde FQDN at the external ALB. Browser ingress is still locked to the
# deployer /32 by the external ALB SG (security.tf).
##################################################

resource "aws_route53_record" "horde_public" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = local.horde_public_fqdn
  type    = "A"

  alias {
    name                   = module.horde.external_alb_dns_name
    zone_id                = module.horde.external_alb_zone_id
    evaluate_target_health = false
  }
}
