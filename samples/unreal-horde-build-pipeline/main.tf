##########################################
# Perforce (Helix Core / P4 Server) — JT-06
#
# Deployed only when the user has NOT supplied an existing Perforce endpoint.
#
# The perforce module input is a p4_server_config OBJECT; there is NO single
# endpoint output, so the P4PORT (local.perforce_endpoint) is constructed from
# the server's private IP in locals.tf.
#
# The P4 Server is placed in a PRIVATE application subnet. External P4 access is
# handled via cross-module security-group rules locked to local.my_ip_cidr in a
# later stage (JT-08) — this sample never opens 0.0.0.0/0 ingress.
#
# The module creates its own super/admin secrets (exposed as ARNs). We do NOT
# recreate them here. See the "Horde P4 credentials secret" block below for why
# a separate, differently-shaped secret is required for the Horde module.
##########################################

module "perforce" {
  source = "../../modules/perforce"

  count = local.deploy_perforce ? 1 : 0

  # - Shared -
  project_prefix = var.project_prefix
  vpc_id         = aws_vpc.horde_pipeline_vpc.id

  # This sample owns its DNS (dns.tf, JT-11); do NOT let the module create a
  # conflicting private hosted zone.
  create_route53_private_hosted_zone = false

  # This sample manages the shared Perforce load balancers itself in a later
  # stage; keep the module's shared LBs disabled so it does not create
  # public-facing balancers we do not control.
  create_shared_network_load_balancer     = false
  create_shared_application_load_balancer = false

  # - P4 Server Configuration -
  p4_server_config = {
    # General
    name                        = "p4-server"
    fully_qualified_domain_name = local.perforce_internal_fqdn

    # Compute
    p4_server_type = "p4d_commit"

    # Storage — sized for a sample commit server. Depot holds versioned files,
    # metadata holds the db.* files, logs holds journal/log output.
    storage_type         = "EBS"
    depot_volume_size    = 512
    metadata_volume_size = 64
    logs_volume_size     = 32

    # Networking & Security — private subnet, no public IP.
    instance_subnet_id = aws_subnet.private_app_subnets[0].id
    internal           = true
  }
}

##########################################
# Horde P4 Credentials Secret — JT-06
#
# The Horde module's `p4_credentials_secret_arn` expects a secret whose value is
# a JSON object: {"username": "...", "password": "..."}. This is a DIFFERENT
# shape than the perforce module's super-password secret (which stores a bare
# password string), so the module's secret cannot be passed to Horde directly.
#
# We therefore create a purpose-built secret for the dedicated Perforce user
# that Horde authenticates as (e.g. a "svc-horde" account).
#
# IMPORTANT (post-deploy step): the password generated here is a PLACEHOLDER so
# that nothing real is hardcoded and Terraform can create the secret. After the
# P4 Server is up, the operator must create/align the Horde P4 user
# (local.horde_p4_username) with THIS password, e.g.:
#     p4 -u <super> passwd svc-horde   # set to the value in this secret
# or update this secret's value to match the password set on the P4 user.
# Rotating either side without the other will break Horde's Perforce connection.
##########################################

resource "random_password" "horde_p4" {
  count = local.deploy_perforce ? 1 : 0

  length  = 24
  special = true
  # Keep to a P4-safe special-character set.
  override_special = "!#$%&*()-_=+[]{}"
}

resource "aws_secretsmanager_secret" "horde_p4_credentials" {
  count = local.deploy_perforce ? 1 : 0

  name        = "${local.name_prefix}-horde-p4-credentials"
  description = "Perforce username/password (JSON) the Horde server authenticates with. Shape: {\"username\":\"...\",\"password\":\"...\"}."

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-horde-p4-credentials"
  })

  #checkov:skip=CKV2_AWS_57: Automatic rotation is out of scope for this sample
}

resource "aws_secretsmanager_secret_version" "horde_p4_credentials" {
  count = local.deploy_perforce ? 1 : 0

  secret_id = aws_secretsmanager_secret.horde_p4_credentials[0].id
  secret_string = jsonencode({
    username = local.horde_p4_username
    password = random_password.horde_p4[0].result
  })
}

##########################################
# ACM Certificate for the Horde HTTPS endpoint — JT-07 (partial)
#
# The Horde module requires a `certificate_arn` for its external ALB HTTPS
# listener. We create a DNS-validated certificate for the public Horde FQDN
# against the existing public hosted zone.
#
# DEFERRED to JT-11 (dns.tf): the public A/ALIAS record pointing the Horde FQDN
# at the external ALB. The certificate's DNS *validation* records are created
# here so the cert can validate independently of the ALB record.
##########################################

data "aws_route53_zone" "public" {
  name         = var.route53_public_hosted_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "horde" {
  domain_name       = local.horde_public_fqdn
  validation_method = "DNS"

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-horde-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "horde_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.horde.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.public.zone_id
}

resource "aws_acm_certificate_validation" "horde" {
  certificate_arn         = aws_acm_certificate.horde.arn
  validation_record_fqdns = [for record in aws_route53_record.horde_cert_validation : record.fqdn]
}

##########################################
# Horde Agent AMIs — JT-07
##########################################

# Amazon Linux 2023 — used for the network-optimized Sync Agent pool.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Windows Server 2022 — used for the compute-optimized Build Agent pool
# (Unreal Engine from-source compiles run on Windows).
data "aws_ami" "windows2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

##########################################
# Unreal Engine Horde — JT-07
#
# - Service tasks run in the PRIVATE application subnets.
# - External ALB (browser access to the Horde UI) is placed in the PUBLIC
#   subnets. Its ingress is locked to local.my_ip_cidr via cross-module SG
#   rules in JT-08 — this sample never opens 0.0.0.0/0.
# - Internal ALB (agent enrollment / in-VPC traffic) is placed in the PRIVATE
#   application subnets.
#
# SECURITY NOTE (auth): auth_method is intentionally left unset here. The Horde
# module does not require it for `terraform validate`, and we must NOT expose a
# public unauthenticated Horde. Authentication (OIDC/Okta/Horde accounts) is
# configured in a later phase. TODO(JT-later): configure auth_method + OIDC vars
# before this internet-reachable ALB is opened to real users.
##########################################

module "horde" {
  source = "../../modules/unreal/horde"

  # - Shared -
  project_prefix = var.project_prefix
  vpc_id         = aws_vpc.horde_pipeline_vpc.id

  # - Networking -
  unreal_horde_service_subnets = aws_subnet.private_app_subnets[*].id

  create_external_alb               = true
  create_internal_alb               = true
  unreal_horde_external_alb_subnets = aws_subnet.public_subnets[*].id
  unreal_horde_internal_alb_subnets = aws_subnet.private_app_subnets[*].id

  # - HTTPS / DNS -
  fully_qualified_domain_name = local.horde_public_fqdn
  certificate_arn             = aws_acm_certificate_validation.horde.certificate_arn

  # - Server image -
  image                         = var.horde_server_image
  github_credentials_secret_arn = var.github_credentials_secret_arn

  # - Perforce wiring -
  # p4_port is ssl:<host>:1666 (built in locals.tf). The credentials secret is
  # the purpose-built JSON secret created in JT-06 above.
  p4_port                   = local.perforce_endpoint
  p4_credentials_secret_arn = local.deploy_perforce ? aws_secretsmanager_secret.horde_p4_credentials[0].arn : null

  # - Agents -
  enable_new_agents_by_default = var.enable_new_agents_by_default

  agents = {
    # Network-optimized Linux pool: performs p4 sync + snapshot into the FSxN
    # source volume. Always-on single instance.
    sync-agent = {
      ami             = data.aws_ami.al2023.id
      instance_type   = var.sync_agent_instance_type
      min_size        = 1
      max_size        = 1
      horde_pool_name = "SyncPool"
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 200
          }
        }
      ]
    }

    # Compute-optimized Windows pool: clones the FSxN snapshot and compiles the
    # engine. Scales from 0 to var.build_agent_max_count. Larger root volume for
    # from-source engine builds.
    build-agent = {
      ami             = data.aws_ami.windows2022.id
      instance_type   = var.build_agent_instance_type
      min_size        = 0
      max_size        = var.build_agent_max_count
      horde_pool_name = "BuildPool"
      block_device_mappings = [
        {
          device_name = "/dev/sda1"
          ebs = {
            volume_size = 500
          }
        }
      ]
    }
  }
}
