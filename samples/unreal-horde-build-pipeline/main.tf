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
  # a pre-created JSON secret ({"username":"...","password":"..."}) passed via
  # var.horde_p4_credentials_secret_arn. Passing a pre-created secret keeps its
  # ARN known at plan time so the Horde module's count logic resolves cleanly.
  p4_port                   = local.perforce_endpoint
  p4_credentials_secret_arn = var.horde_p4_credentials_secret_arn

  # - Horde configuration (globals.json) — JT-18 -
  #
  # We render config/horde/globals.json.tpl (injecting var.perforce_stream) and
  # pass the JSON INLINE via config_globals_json. The module's init container
  # writes that rendered JSON to /app/Data/globals.json, and the app loads it
  # because config_path = "globals.json" sets configPath in server.json
  # (verified: ecs.tf init container write logic + local.tf server_json.configPath).
  #
  # globals.json references the Perforce connection by clusterName = "default",
  # which the module already defines in server.json
  # (plugins.build.perforce[{ id: "default", ... }]) — so we do NOT redefine
  # perforceClusters/credentials in globals.json.
  #
  # NOTE: JT-18's original plan called for an "extra_environment" input; that
  # variable does not exist on this module. config_globals_json + config_path is
  # the supported mechanism.
  # The BuildGraph <Option>s in buildgraph/*.xml have no DefaultValue, so every
  # one of them must be injected here as a -set: argument in the template. A
  # missing value fails the job at graph-parse time (before any ONTAP call), so
  # adding an Option to the XML means adding it in BOTH places. See the
  # DELIBERATELY NOT SET HERE note in globals.json.tpl for the three per-run
  # values (SnapshotName / SnapshotChangelist / CloneVolumeName) that must be
  # supplied per job rather than baked into config.
  config_globals_json = templatefile("${path.module}/config/horde/globals.json.tpl", {
    perforce_stream = var.perforce_stream
    aws_region      = var.region

    fsxn_source_volume_name = local.fsxn_source_volume_name
    fsxn_svm_name           = local.fsxn_svm_name

    # SAN identifiers. The LUN inside the volume is what hosts mount.
    fsxn_lun_name        = local.fsxn_lun_name
    fsxn_lun_size        = var.fsxn_lun_size
    fsxn_hydrator_igroup = local.fsxn_hydrator_igroup
    fsxn_agent_igroup    = local.fsxn_agent_igroup

    # iSCSI portal addresses, comma-separated. The scripts connect exactly ONE
    # unless MPIO is installed - two without MPIO make Windows see one LUN as two
    # disks.
    fsxn_iscsi_portals = local.fsxn_iscsi_portals

    fsxn_source_drive_letter = local.fsxn_source_drive_letter
    fsxn_clone_drive_letter  = local.fsxn_clone_drive_letter

    # Management endpoint for the ONTAP REST API (snapshot / FlexClone / LUN
    # calls). A DNS name works: the scripts only interpolate it into
    # https://<host>/api/..., and it survives file-system replacement.
    fsxn_management_ip = aws_fsx_ontap_file_system.workspace.endpoints[0].management[0].dns_name

    fsxn_admin_secret_name = aws_secretsmanager_secret.fsxn_admin.name

    p4_port = local.perforce_endpoint == null ? "" : local.perforce_endpoint
    p4_user = local.horde_p4_username
  })
  config_path = "globals.json"

  # - Agents -
  enable_new_agents_by_default = var.enable_new_agents_by_default

  agents = {
    # Hydrator pool: p4 syncs the source LUN and snapshots it as cl-{N}.
    #
    # WINDOWS, NOT LINUX - this changed with the move to iSCSI and it is not a
    # preference. The source LUN carries NTFS, so its writer must be Windows. It
    # must also be the ONLY writer (NTFS is not a shared filesystem), which is why
    # min=max=1 here and why the source LUN is mapped to a single-host igroup.
    # Raising max_size above 1 would put two hosts on one NTFS volume;
    # hydrate-source-lun.ps1 will refuse rather than let that happen, so a second
    # instance simply fails its lease.
    sync-agent = {
      ami             = data.aws_ami.windows2022.id
      instance_type   = var.sync_agent_instance_type
      min_size        = 1
      max_size        = 1
      horde_pool_name = "SyncPool"
      block_device_mappings = [
        {
          # Windows root device, and larger than the old Linux 200 GB: the
          # workspace itself lives on the LUN, but Windows + the toolchain need
          # room on C:.
          device_name = "/dev/sda1"
          ebs = {
            volume_size = 300
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

##########################################
# Validation: bundled-Perforce requires a pre-created P4 credentials secret
#
# When the sample deploys the bundled Perforce server
# (existing_perforce_server_endpoint = null), a pre-created Horde P4 credentials
# secret ARN MUST be supplied via var.horde_p4_credentials_secret_arn. Passing a
# pre-created secret keeps its ARN known at plan time so the Horde module's
# count logic resolves without an unknown-count error. This is expressed as a
# check block because it depends on two variables (cross-variable) and cannot be
# a single-variable validation.
##########################################
check "horde_p4_credentials_secret_required" {
  assert {
    condition     = !local.deploy_perforce || var.horde_p4_credentials_secret_arn != null
    error_message = "var.horde_p4_credentials_secret_arn must be set when deploying the bundled Perforce server (existing_perforce_server_endpoint = null)."
  }
}
