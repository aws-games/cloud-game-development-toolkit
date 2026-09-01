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

  fsxn_source_volume_name   = "p4_workspace"
  fsxn_source_junction_path = "/p4-workspace"
  fsxn_svm_name             = "workspace"

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
  # operator must align this user's password with the secret post-deploy. Now
  # surfaced as a NON-SECRET sample variable so operators can override it to
  # match their secret's "username" without editing locals. Rendered into
  # globals.json's perforceClusters "default" cluster as serviceAccount.
  horde_p4_username = var.horde_p4_service_account_username

  # P4PORT split into colon-free components for delivery to the sync-agent
  # SSM association's ExtraVariables. The AWS-ApplyAnsiblePlaybooks
  # ExtraVariables parameter rejects ':' entirely (even inside quotes), so we
  # cannot pass the raw ssl:<host>:1666 P4PORT. Instead we pass scheme/host/port
  # separately and the playbook reassembles P4PORT for `p4 trust`. When no
  # Perforce endpoint exists these are empty and the playbook skips SSL trust.
  #   perforce_endpoint format: "<scheme>:<host>:<port>" e.g. "ssl:10.0.10.51:1666"
  perforce_endpoint_parts = local.perforce_endpoint == null ? [] : split(":", local.perforce_endpoint)
  perforce_scheme         = length(local.perforce_endpoint_parts) == 3 ? local.perforce_endpoint_parts[0] : ""
  perforce_host           = length(local.perforce_endpoint_parts) == 3 ? local.perforce_endpoint_parts[1] : ""
  perforce_port_num       = length(local.perforce_endpoint_parts) == 3 ? local.perforce_endpoint_parts[2] : ""

  ##################################################
  # Tags
  ##################################################

  tags = {
    Project   = "unreal-horde-build-pipeline"
    ManagedBy = "terraform"
  }
}
