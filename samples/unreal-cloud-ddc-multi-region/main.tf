resource "awscc_secretsmanager_secret" "unreal_cloud_ddc_token" {
  name        = "unreal-cloud-ddc-bearer-token-multi-region"
  description = "The token to access unreal cloud ddc sample."
  generate_secret_string = {
    exclude_punctuation = true
    exclude_numbers     = false
    include_space       = false
    password_length     = 64
  }
  replica_regions = [{
    region = var.regions[1]
  }]
  provider = awscc.region-1
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token_region_1" {
  depends_on = [awscc_secretsmanager_secret.unreal_cloud_ddc_token]
  region     = var.regions[0]
  secret_id  = awscc_secretsmanager_secret.unreal_cloud_ddc_token.id
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token_region_2" {
  depends_on = [awscc_secretsmanager_secret.unreal_cloud_ddc_token]
  region     = var.regions[1]
  secret_id  = awscc_secretsmanager_secret.unreal_cloud_ddc_token.name
}


data "http" "public_ip" {
  url = "https://checkip.amazonaws.com/"
}

################################################################################
# VPC US-WEST-2
################################################################################

# us-west-2 VPC and security group

module "unreal_cloud_ddc_vpc_region_1" {
  source                = "./vpc"
  vpc_cidr              = local.vpc_cidr_block_region_1
  private_subnets_cidrs = local.private_subnets_cidrs_region_1
  public_subnets_cidrs  = local.public_subnets_cidrs_region_1
  region                = var.regions[0]
  availability_zones    = local.azs_region_1
  additional_tags       = local.tags
}

resource "aws_security_group" "unreal_ddc_load_balancer_access_security_group_region_1" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to a resource
  name        = "cgd-load-balancer-sg"
  description = "Access unreal ddc load balancer"
  region      = var.regions[0]
  vpc_id      = module.unreal_cloud_ddc_vpc_region_1.vpc_id

  tags = local.tags
}
resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_http_ingress_rule_region_1" {
  count             = var.allow_my_ip ? 1 : 0
  region            = var.regions[0]
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_http2_ingress_rule_region_1" {
  count             = var.allow_my_ip ? 1 : 0
  region            = var.regions[0]
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_https_ingress_rule_region_1" {
  count             = var.allow_my_ip ? 1 : 0
  region            = var.regions[0]
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_egress_rule" "unreal_ddc_load_balancer_egress_sg_rules_region_1" {
  region            = var.regions[0]
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


################################################################################
# VPC region_2
################################################################################

module "unreal_cloud_ddc_vpc_region_2" {
  source                = "./vpc"
  vpc_cidr              = local.vpc_cidr_block_region_2
  private_subnets_cidrs = local.private_subnets_cidrs_region_2
  public_subnets_cidrs  = local.public_subnets_cidrs_region_2
  region                = var.regions[1]
  availability_zones    = local.azs_region_2
  additional_tags       = local.tags
}

resource "aws_security_group" "unreal_ddc_load_balancer_access_security_group_region_2" {
  #checkov:skip=CKV2_AWS_5: Security group is attached to a resource
  name        = "cgd-load-balancer-sg"
  description = "Access unreal ddc load balancer"
  vpc_id      = module.unreal_cloud_ddc_vpc_region_2.vpc_id
  region      = var.regions[1]

  tags = local.tags
}


resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_http_ingress_rule_region_2" {
  count             = var.allow_my_ip ? 1 : 0
  region            = var.regions[1]
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_http2_ingress_rule_region_2" {
  count             = var.allow_my_ip ? 1 : 0
  region            = var.regions[1]
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_https_ingress_rule_region_2" {
  count             = var.allow_my_ip ? 1 : 0
  region            = var.regions[1]
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_egress_rule" "unreal_ddc_load_balancer_egress_sg_rules_region_2" {
  region            = var.regions[1]
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# VPC Peering Connection
################################################################################

# Peering connection between region 1 vpc and region 2 vpc
resource "aws_vpc_peering_connection" "vpc_connection_region_1_to_region_2" {
  region        = var.regions[0]
  vpc_id        = module.unreal_cloud_ddc_vpc_region_1.vpc_id
  peer_owner_id = data.aws_caller_identity.current.account_id
  peer_vpc_id   = module.unreal_cloud_ddc_vpc_region_2.vpc_id
  peer_region   = var.regions[1]

  tags = local.tags
}

resource "aws_vpc_peering_connection_accepter" "region_2" {
  region                    = var.regions[1]
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_connection_region_1_to_region_2.id
  auto_accept               = true
  tags                      = local.tags
}

resource "aws_vpc_peering_connection_options" "requester" {
  depends_on                = [aws_vpc_peering_connection_accepter.region_2]
  region                    = var.regions[0]
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_connection_region_1_to_region_2.id
  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  depends_on                = [aws_vpc_peering_connection_accepter.region_2]
  region                    = var.regions[1]
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_connection_region_1_to_region_2.id
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "vpc_region_1_to_region_2" {
  region                    = var.regions[0]
  route_table_id            = module.unreal_cloud_ddc_vpc_region_1.vpc_private_route_table_id
  destination_cidr_block    = local.vpc_cidr_block_region_2
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_connection_region_1_to_region_2.id
}

resource "aws_route" "vpc_region_2_to_region_1" {
  region                    = var.regions[1]
  route_table_id            = module.unreal_cloud_ddc_vpc_region_2.vpc_private_route_table_id
  destination_cidr_block    = local.vpc_cidr_block_region_1
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_connection_region_1_to_region_2.id
}

################################################################################
# Multi Region with Token
################################################################################

# us-west-2 resources

module "unreal_cloud_ddc_infra_region_1" {
  source = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra"
  name   = "unreal-cloud-ddc"
  vpc_id = module.unreal_cloud_ddc_vpc_region_1.vpc_id
  region = var.regions[0]

  eks_node_group_subnets                  = module.unreal_cloud_ddc_vpc_region_1.private_subnet_ids
  eks_cluster_public_endpoint_access_cidr = ["${chomp(data.http.public_ip.response_body)}/32"]
  eks_cluster_private_access              = true
  eks_cluster_public_access               = true
  existing_security_groups                = [aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id]

  is_primary_region         = true
  scylla_replication_factor = 3
  scylla_subnets            = module.unreal_cloud_ddc_vpc_region_1.private_subnet_ids
  scylla_ami_name           = local.scylla_ami_name
  scylla_architecture       = local.scylla_architecture
  scylla_instance_type      = local.scylla_instance_type
  existing_scylla_ips       = module.unreal_cloud_ddc_infra_region_2.scylla_ips
  scylla_ips_by_region      = local.scylla_ips_by_region

  scylla_db_throughput = 200
  scylla_db_storage    = 100

  monitoring_application_load_balancer_subnets = module.unreal_cloud_ddc_vpc_region_1.public_subnet_ids
  alb_certificate_arn                          = aws_acm_certificate.scylla_monitoring_region_1.arn

  nvme_managed_node_instance_type = local.nvme_managed_node_instance_type
  nvme_managed_node_desired_size  = 2

  worker_managed_node_instance_type = local.worker_managed_node_instance_type
  worker_managed_node_desired_size  = 1

  system_managed_node_instance_type = local.system_managed_node_instance_type
  system_managed_node_desired_size  = 1
}

# Security groups for cross region communication

resource "aws_vpc_security_group_ingress_rule" "scylla_db_region_1_to_2" {
  description       = "Allow communication between scyllaDB nodes across VPCs"
  region            = var.regions[0]
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "TCP"
  cidr_ipv4         = local.vpc_cidr_block_region_2
  security_group_id = module.unreal_cloud_ddc_infra_region_1.scylla_security_group
}

module "unreal_cloud_ddc_intra_cluster_region_1" {
  depends_on = [
    module.unreal_cloud_ddc_infra_region_1,
    module.unreal_cloud_ddc_infra_region_1.oidc_provider_arn
  ]

  source                              = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster"
  region                              = var.regions[0]
  is_multi_region_deployment          = true
  cluster_name                        = module.unreal_cloud_ddc_infra_region_1.cluster_name
  cluster_oidc_provider_arn           = module.unreal_cloud_ddc_infra_region_1.oidc_provider_arn
  ghcr_credentials_secret_manager_arn = var.github_credential_arn_region_1
  s3_bucket_id                        = module.unreal_cloud_ddc_infra_region_1.s3_bucket_id


  unreal_cloud_ddc_helm_base_infra_chart  = "${path.module}/assets/unreal_cloud_ddc_multi_region_base.yaml"
  unreal_cloud_ddc_helm_replication_chart = "${path.module}/assets/unreal_cloud_ddc_multi_region.yaml"

  unreal_cloud_ddc_helm_config = {
    scylla_ips             = join(",", local.scylla_ips)
    bucket_name            = module.unreal_cloud_ddc_infra_region_1.s3_bucket_id
    region                 = replace(var.regions[0], "-1", "")
    replication_region     = replace(var.regions[1], "-1", "")
    aws_region             = var.regions[0]
    aws_replication_region = var.regions[1]
    ddc_region             = replace(var.regions[0], "-", "_")
    security_group_ids     = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
    token                  = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_1.secret_string
  }


  providers = {
    kubernetes = kubernetes.region-1,
    helm       = helm.region-1
    aws        = aws.region-1
  }
}

# region_2 resources

module "unreal_cloud_ddc_infra_region_2" {
  source = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra"
  name   = "unreal-cloud-ddc"
  vpc_id = module.unreal_cloud_ddc_vpc_region_2.vpc_id
  region = var.regions[1]

  eks_node_group_subnets                  = module.unreal_cloud_ddc_vpc_region_2.private_subnet_ids
  eks_cluster_public_endpoint_access_cidr = ["${chomp(data.http.public_ip.response_body)}/32"]
  eks_cluster_private_access              = true
  eks_cluster_public_access               = true
  existing_security_groups                = [aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id]

  is_primary_region                = false
  scylla_replication_factor        = 3
  existing_scylla_seed             = module.unreal_cloud_ddc_infra_region_1.scylla_seed
  create_scylla_monitoring_stack   = false
  create_application_load_balancer = false
  scylla_subnets                   = module.unreal_cloud_ddc_vpc_region_2.private_subnet_ids
  scylla_ami_name                  = local.scylla_ami_name
  scylla_architecture              = local.scylla_architecture
  scylla_instance_type             = local.scylla_instance_type

  scylla_db_throughput = 200
  scylla_db_storage    = 100

  nvme_managed_node_instance_type = local.nvme_managed_node_instance_type
  nvme_managed_node_desired_size  = 2

  worker_managed_node_instance_type = local.worker_managed_node_instance_type
  worker_managed_node_desired_size  = 1

  system_managed_node_instance_type = local.system_managed_node_instance_type
  system_managed_node_desired_size  = 1
}

# cross region communication for scylla
resource "aws_vpc_security_group_ingress_rule" "scylla_db_region_2_to_1" {
  description       = "Allow communication between scyllaDB nodes across VPCs"
  region            = var.regions[1]
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "TCP"
  cidr_ipv4         = local.vpc_cidr_block_region_1
  security_group_id = module.unreal_cloud_ddc_infra_region_2.scylla_security_group
}

# # Cross region load balancing

resource "aws_vpc_security_group_ingress_rule" "unreal_cloud_ddc_cluster_region_1_to_lb_region_2" {
  description       = "Allow communication between unreal cloud ddc clusters via load balancers"
  region            = var.regions[0]
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "TCP"
  cidr_ipv4         = local.vpc_cidr_block_region_2
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
}

resource "aws_vpc_security_group_ingress_rule" "unreal_cloud_ddc_cluster_region_1_to_lb_region_2_http" {
  description       = "Allow communication between unreal cloud ddc clusters via load balancers"
  region            = var.regions[0]
  from_port         = 80
  to_port           = 80
  ip_protocol       = "TCP"
  cidr_ipv4         = local.vpc_cidr_block_region_2
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
}


resource "aws_vpc_security_group_ingress_rule" "unreal_cloud_ddc_cluster_region_2_to_lb_region_1" {
  description       = "Allow communication between unreal cloud ddc clusters via load balancers"
  region            = var.regions[1]
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "TCP"
  cidr_ipv4         = local.vpc_cidr_block_region_1
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
}

resource "aws_vpc_security_group_ingress_rule" "unreal_cloud_ddc_cluster_region_2_to_lb_region_1_http" {
  description       = "Allow communication between unreal cloud ddc clusters via load balancers"
  region            = var.regions[1]
  from_port         = 80
  to_port           = 80
  ip_protocol       = "TCP"
  cidr_ipv4         = local.vpc_cidr_block_region_1
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
}


module "unreal_cloud_ddc_intra_cluster_region_2" {
  depends_on = [
    module.unreal_cloud_ddc_infra_region_2,
    module.unreal_cloud_ddc_infra_region_2.oidc_provider_arn
  ]

  source                              = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster"
  region                              = var.regions[1]
  is_multi_region_deployment          = true
  cluster_name                        = module.unreal_cloud_ddc_infra_region_2.cluster_name
  cluster_oidc_provider_arn           = module.unreal_cloud_ddc_infra_region_2.oidc_provider_arn
  ghcr_credentials_secret_manager_arn = var.github_credential_arn_region_2
  s3_bucket_id                        = module.unreal_cloud_ddc_infra_region_2.s3_bucket_id

  unreal_cloud_ddc_helm_base_infra_chart  = "${path.module}/assets/unreal_cloud_ddc_multi_region_base.yaml"
  unreal_cloud_ddc_helm_replication_chart = "${path.module}/assets/unreal_cloud_ddc_multi_region.yaml"

  unreal_cloud_ddc_helm_config = {
    scylla_ips             = join(",", local.scylla_ips)
    bucket_name            = module.unreal_cloud_ddc_infra_region_2.s3_bucket_id
    region                 = replace(var.regions[1], "-1", "")
    replication_region     = replace(var.regions[0], "-1", "")
    aws_region             = var.regions[1]
    aws_replication_region = var.regions[0]
    ddc_region             = replace(var.regions[1], "-", "_")
    security_group_ids     = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
    token                  = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_2.secret_string
  }


  providers = {
    kubernetes = kubernetes.region-2,
    helm       = helm.region-2
    aws        = aws.region-2
  }
}

# Create ssm resource to do a run command on the scylladb instances.
# We need this because in order to ensure the local replication strategy is correct
# Note we have to alter the table 3 times due to a limitation where only one DC's RF can be changed at a time and not by more than 1
resource "aws_ssm_document" "unreal_cloud_ddc_scylla_update_document" {
  depends_on = [
    module.unreal_cloud_ddc_intra_cluster_region_1,
    module.unreal_cloud_ddc_intra_cluster_region_2
  ]
  name            = "update_keyspaces_document"
  document_format = "YAML"
  document_type   = "Command"

  content = <<DOC
schemaVersion: '1.2'
description: Alter the keyspaces of each of the local keyspaces in ScyllaDB nodes to set the replication factor to 0 for the new region.
parameters:
  regions:
    type: String
    description: Regions to include as datacenters
    default: ${var.regions[0]},${var.regions[1]}
runtimeConfig:
  aws:runShellScript:
    properties:
      - id: 0.aws:runShellScript
        runCommand:
          - |
            cqlsh --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.regions[0], "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${replace(var.regions[0], "-1", "")}': 0, '${replace(var.regions[1], "-1", "")}': 0};" && \
            cqlsh --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.regions[0], "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${replace(var.regions[0], "-1", "")}': 1, '${replace(var.regions[1], "-1", "")}': 0};" && \
            cqlsh --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.regions[0], "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${replace(var.regions[0], "-1", "")}': 2, '${replace(var.regions[1], "-1", "")}': 0};" && \
            cqlsh --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.regions[1], "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${replace(var.regions[1], "-1", "")}': 0, '${replace(var.regions[0], "-1", "")}': 0};" && \
            cqlsh --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.regions[1], "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${replace(var.regions[1], "-1", "")}': 1, '${replace(var.regions[0], "-1", "")}': 0};" && \
            cqlsh --request-timeout=120 -e "ALTER KEYSPACE jupiter_local_ddc_${replace(var.regions[1], "-", "_")} WITH replication = {'class': 'NetworkTopologyStrategy', '${replace(var.regions[1], "-1", "")}': 2, '${replace(var.regions[0], "-1", "")}': 0};"
DOC
}

resource "aws_ssm_association" "unreal_cloud_ddc_scylla_db_association" {
  depends_on = [
    aws_ssm_document.unreal_cloud_ddc_scylla_update_document,
    module.unreal_cloud_ddc_intra_cluster_region_1,
    module.unreal_cloud_ddc_intra_cluster_region_2
  ]
  name = aws_ssm_document.unreal_cloud_ddc_scylla_update_document.name
  targets {
    key    = "InstanceIds"
    values = [module.unreal_cloud_ddc_infra_region_1.scylla_seed_instance_id]
  }
}


