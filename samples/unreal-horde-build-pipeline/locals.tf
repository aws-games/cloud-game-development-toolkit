##################################################
# Data Sources
##################################################

data "aws_availability_zones" "available" {}

# Deployer's public IP — used to lock down every externally-reachable ingress
# rule to a single /32. There are NO 0.0.0.0/0 ingress rules in this sample.
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

##################################################
# Local Variables
##################################################

locals {
  # Project Configuration
  name_prefix = "${var.project_prefix}-horde-pipeline"
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  my_ip       = chomp(data.http.my_ip.response_body)

  # Single-IP CIDR for all external ingress lockdown.
  my_ip_cidr = "${local.my_ip}/32"

  ##################################################
  # Subdomains & FQDNs
  ##################################################

  perforce_subdomain = var.perforce_server_name
  horde_subdomain    = "horde"

  # Internal (private zone) FQDNs for service discovery.
  perforce_internal_fqdn = "${local.perforce_subdomain}.${var.route53_private_zone_name}"
  horde_internal_fqdn    = "${local.horde_subdomain}.${var.route53_private_zone_name}"

  # Public FQDN for the Horde HTTPS endpoint.
  horde_public_fqdn = var.certificate_domain

  ##################################################
  # VPC & Networking Configuration
  #
  # 3-tier layout across 2 AZs:
  #   public       - ALBs / NAT
  #   private-app  - Horde ECS tasks, Perforce, agents
  #   private-svc  - FSxN, DocumentDB, ElastiCache
  ##################################################

  vpc_cidr_block = var.vpc_cidr

  public_subnet_cidrs      = ["10.0.0.0/24", "10.0.1.0/24"]
  private_app_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  private_svc_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

  ##################################################
  # FSx for ONTAP
  ##################################################

  fsxn_source_volume_name = "p4_workspace"
  fsxn_svm_name           = "workspace"

  # Unused on the SAN path, but FSx CreateVolume rejects a volume without a
  # junction path, so one must exist. Nothing NFS-mounts this volume.
  fsxn_source_junction_path = "/p4-workspace"

  # The LUN inside the source volume. This is what hosts actually mount, as
  # /vol/<volume>/<lun>. ONTAP object names reject hyphens (an opaque HTTP 400),
  # so keep underscores here and in any generated clone name.
  fsxn_lun_name = "workspace"

  # TWO IGROUPS, ON PURPOSE - this is a correctness boundary, not tidiness.
  #
  # NTFS is not a shared filesystem: a LUN has exactly one legitimate writer.
  #   * hydrator igroup: SINGLE host. Owns the source LUN. hydrate-source-lun.ps1
  #     passes -SingleHost, so if this igroup already holds a different initiator
  #     the run FAILS rather than becoming a second writer on one filesystem.
  #   * agents igroup: shared across build agents, which is safe because every
  #     per-job clone LUN is used by exactly one job on one agent.
  # Mapping the SOURCE LUN to the shared igroup would let two agents mount one
  # NTFS volume read-write. Do not do it.
  fsxn_hydrator_igroup = "horde_san_hydrator"
  fsxn_agent_igroup    = "horde_san_agents"

  # Drive letters. The hydrator holds the source LUN; build agents get per-job
  # clone LUNs. Distinct letters keep a misconfigured agent from appearing to
  # succeed against the wrong volume.
  fsxn_source_drive_letter = "S"
  fsxn_clone_drive_letter  = "W"

  # SVM iSCSI portal addresses, comma-separated for the BuildGraph -set: option.
  # NOTE the scripts connect exactly ONE of these unless the Windows MPIO feature
  # is installed: two portals without MPIO make Windows enumerate a single LUN as
  # two separate disks, which is a corruption trap.
  fsxn_iscsi_portals = join(",", aws_fsx_ontap_storage_virtual_machine.workspace.endpoints[0].iscsi[0].ip_addresses)

  ##################################################
  # Perforce
  ##################################################

  # The perforce module has NO single endpoint output. When the sample deploys
  # Perforce, construct the P4PORT from the server's private IP.
  deploy_perforce = var.existing_perforce_server_endpoint == null

  perforce_endpoint = coalesce(
    var.existing_perforce_server_endpoint,
    local.deploy_perforce ? "ssl:${module.perforce[0].p4_server_private_ip}:1666" : null
  )

  # Dedicated Perforce user that the Horde server authenticates as. The
  # purpose-built Horde P4 credentials secret (JT-06) stores this username; the
  # operator must align this user's password with the secret post-deploy.
  horde_p4_username = "svc-horde"

  ##################################################
  # Tags
  ##################################################

  tags = {
    Project   = "unreal-horde-build-pipeline"
    ManagedBy = "terraform"
  }
}
