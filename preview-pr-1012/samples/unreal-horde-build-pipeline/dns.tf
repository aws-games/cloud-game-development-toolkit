##################################################
# DNS
#
# This sample OWNS its DNS. The perforce module is deployed with
# create_route53_private_hosted_zone = false, so we create the private hosted
# zone here and associate it with the VPC. Records:
#   * private: perforce.{private_zone} -> P4 Server private IP (A)
#   * private: horde.{private_zone}    -> Horde internal ALB (ALIAS A)
#   * public:  {horde_public_fqdn}     -> Horde external ALB (ALIAS A)
#
# The public record completes the browser-facing endpoint begun in main.tf
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
  #checkov:skip=CKV2_AWS_23:The attached resource is managed by CGD Toolkit
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
# Public record — Horde external ALB
#
# The ACM certificate and its DNS validation records were created in main.tf
# against data.aws_route53_zone.public. This ALIAS points the public
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

##################################################
# Split-Horizon Private Override of the Horde FQDN
#
# Private-subnet Horde agents must enroll against the *public* FQDN
# (local.horde_public_fqdn = var.certificate_domain) because that is the name
# embedded in the agent's server config and in the ACM certificate. The real
# public hosted zone points that FQDN at the EXTERNAL ALB, whose SG is locked to
# the deployer /32 — so in-VPC agents cannot reach it.
#
# To fix this WITHOUT relaxing any SG or changing the cert, we create a PRIVATE
# hosted zone associated ONLY with this sample's VPC and put the override at its
# apex. Route 53 answers in-VPC queries from the most specific matching private
# zone, so:
#   * INSIDE the VPC  -> this zone answers horde.<domain> with the INTERNAL ALB
#                        (agents enroll over 10.0.x.x; TLS is still valid because
#                        the internal ALB serves the same ACM cert).
#   * OUTSIDE the VPC -> the real public zone still answers with the EXTERNAL ALB
#                        (browser traffic, /32-locked), completely unchanged.
#
# THE ZONE IS NAMED AFTER THE FQDN, NOT THE APEX DOMAIN, ON PURPOSE. A private
# zone named after the whole apex domain would shadow the ENTIRE public domain
# inside the VPC: Route 53 never falls back to the public zone for a name under
# a matching private zone — it returns NXDOMAIN — so every other record the
# operator owns under that domain (perforce.<domain>, artifacts.<domain>, ...)
# would stop resolving for the agents and the Horde server. Scoping the zone to
# the single name we override leaves the rest of the domain untouched.
##################################################

resource "aws_route53_zone" "public_split" {
  name = local.horde_public_fqdn

  vpc {
    vpc_id = aws_vpc.horde_pipeline_vpc.id
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-split-zone"
  })

  #checkov:skip=CKV2_AWS_38:Private (split-horizon) hosted zone; DNSSEC not applicable
  #checkov:skip=CKV2_AWS_39:Query logging out of scope for this sample
}

# In-VPC override: public Horde FQDN -> Horde INTERNAL ALB (agent enrollment).
# Mirrors aws_route53_record.horde_internal but uses the public FQDN so agents
# resolving the public name from inside the VPC land on the internal ALB.
resource "aws_route53_record" "horde_public_split" {
  zone_id = aws_route53_zone.public_split.zone_id
  name    = local.horde_public_fqdn
  type    = "A"

  alias {
    name                   = module.horde.internal_alb_dns_name
    zone_id                = module.horde.internal_alb_zone_id
    evaluate_target_health = false
  }
}
