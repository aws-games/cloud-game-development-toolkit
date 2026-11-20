data "aws_availability_zones" "available_region_1" {
  region = var.regions[0]

  # Filter for standard AZs only
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_availability_zones" "available_region_2" {
  region = var.regions[1]

  # Filter for standard AZs only
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_region" "region_1" {
  region = var.regions[0]
}

data "aws_region" "region_2" {
  region = var.regions[1]
}

data "aws_ecr_authorization_token" "token_region_1" {
  region = var.regions[0]
}

data "aws_ecr_authorization_token" "token_region_2" {
  region = var.regions[1]
}

data "aws_caller_identity" "current" {}

locals {
  azs_region_1 = slice(data.aws_availability_zones.available_region_1.names, 0, 2)
  azs_region_2 = slice(data.aws_availability_zones.available_region_2.names, 0, 2)

  vpc_cidr_block_region_1        = "192.168.0.0/17"
  private_subnets_cidrs_region_1 = ["192.168.0.0/24", "192.168.1.0/24"]
  public_subnets_cidrs_region_1  = ["192.168.2.0/24", "192.168.3.0/24"]

  vpc_cidr_block_region_2        = "192.168.128.0/17"
  private_subnets_cidrs_region_2 = ["192.168.128.0/24", "192.168.129.0/24"]
  public_subnets_cidrs_region_2  = ["192.168.130.0/24", "192.168.131.0/24"]

  nvme_managed_node_instance_type   = "i3en.xlarge"
  worker_managed_node_instance_type = "c6i.large"
  system_managed_node_instance_type = "m7i.large"

  scylla_ami_name      = "ScyllaDB 2026.3.1"
  scylla_architecture  = "x86_64"
  scylla_instance_type = "i4i.xlarge"
  # Backward compatible flat list
  scylla_ips = concat(module.unreal_cloud_ddc_infra_region_1.scylla_ips, module.unreal_cloud_ddc_infra_region_2.scylla_ips)

  # New map structure for monitoring
  scylla_ips_by_region = {
    (var.regions[0]) = module.unreal_cloud_ddc_infra_region_1.scylla_ips
    (var.regions[1]) = module.unreal_cloud_ddc_infra_region_2.scylla_ips
  }

  tags = {
    Environment = "cgd"
    Application = "unreal-cloud-ddc"
  }
}

locals {
  eks_endpoint_host_region_1   = replace(module.unreal_cloud_ddc_infra_region_1.cluster_endpoint, "https://", "")
  eks_endpoint_host_region_2   = replace(module.unreal_cloud_ddc_infra_region_2.cluster_endpoint, "https://", "")
  eks_provider_host_region_1   = var.eks_api_local_port_region_1 == null ? module.unreal_cloud_ddc_infra_region_1.cluster_endpoint : "https://127.0.0.1:${var.eks_api_local_port_region_1}"
  eks_provider_host_region_2   = var.eks_api_local_port_region_2 == null ? module.unreal_cloud_ddc_infra_region_2.cluster_endpoint : "https://127.0.0.1:${var.eks_api_local_port_region_2}"
  eks_tls_server_name_region_1 = var.eks_api_local_port_region_1 == null ? null : local.eks_endpoint_host_region_1
  eks_tls_server_name_region_2 = var.eks_api_local_port_region_2 == null ? null : local.eks_endpoint_host_region_2

  # Explicit CIDRs win; otherwise fall back to the auto-detected /32.
  eks_public_access_cidrs = length(var.eks_public_access_cidrs) > 0 ? var.eks_public_access_cidrs : ["${chomp(data.http.public_ip.response_body)}/32"]
}

locals {
  # Client-facing latency name, and one stable name per region. Each region's
  # replicator is pointed at the other region's name at plan time, which breaks
  # the old wait-for-the-peer-load-balancer cycle.
  ddc_dns_name         = "${var.name_prefix}.${data.aws_route53_zone.root.name}"
  ddc_region_hostnames = [for r in var.regions : "${var.name_prefix}-${r}.${data.aws_route53_zone.root.name}"]
}

locals {
  # Who may reach the DDC NLBs and monitoring ALB: explicit CIDRs plus, when
  # allow_my_ip is true, the single IP detected at apply time.
  client_access_cidrs = distinct(concat(
    var.allowed_client_cidrs,
    var.allow_my_ip ? ["${chomp(data.http.public_ip.response_body)}/32"] : []
  ))
}
