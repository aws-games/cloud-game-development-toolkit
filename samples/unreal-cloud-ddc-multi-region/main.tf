resource "random_password" "unreal_ddc" {
  length  = 64
  special = false
  numeric = true
}

resource "aws_secretsmanager_secret" "unreal_cloud_ddc_token" {
  name        = "unreal-cloud-ddc-bearer-token-multi-region"
  description = "The token to access unreal cloud ddc sample."
  region      = var.regions[0]
  replica {
    region = var.regions[1]
  }
  #checkov:skip=CKV_AWS_149: KMS encryption not yet
  #checkov:skip=CKV2_AWS_57: Secret rotation is not required for this sample.
  tags = local.tags
}

data "aws_secretsmanager_secret" "unreal_ddc_region_2" {
  depends_on = [aws_secretsmanager_secret.unreal_cloud_ddc_token]
  region     = var.regions[1]
  name       = aws_secretsmanager_secret.unreal_cloud_ddc_token.name
}

resource "aws_secretsmanager_secret_version" "unreal_ddc" {
  secret_id     = aws_secretsmanager_secret.unreal_cloud_ddc_token.id
  secret_string = random_password.unreal_ddc.result
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token_region_1" {
  depends_on = [aws_secretsmanager_secret.unreal_cloud_ddc_token]
  region     = var.regions[0]
  secret_id  = aws_secretsmanager_secret.unreal_cloud_ddc_token.id
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token_region_2" {
  depends_on = [aws_secretsmanager_secret.unreal_cloud_ddc_token]
  region     = var.regions[1]
  secret_id  = data.aws_secretsmanager_secret.unreal_ddc_region_2.id
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
  vpc_cidr              = "192.168.0.0/17"
  private_subnets_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]
  public_subnets_cidrs  = ["192.168.2.0/24", "192.168.3.0/24"]
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
  vpc_cidr              = "192.168.128.0/17"
  private_subnets_cidrs = ["192.168.128.0/24", "192.168.129.0/24"]
  public_subnets_cidrs  = ["192.168.130.0/24", "192.168.131.0/24"]
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
  region                    = var.regions[0]
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_connection_region_1_to_region_2.id
  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_vpc_peering_connection_options" "accepter" {
  region                    = var.regions[1]
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_connection_region_1_to_region_2.id
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "vpc_region_1_to_region_2" {
  region                    = var.regions[0]
  route_table_id            = module.unreal_cloud_ddc_vpc_region_1.vpc_private_route_table_id
  destination_cidr_block    = "192.168.128.0/17"
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_connection_region_1_to_region_2.id
}

resource "aws_route" "vpc_region_2_to_region_1" {
  region                    = var.regions[1]
  route_table_id            = module.unreal_cloud_ddc_vpc_region_2.vpc_private_route_table_id
  destination_cidr_block    = "192.168.0.0/17"
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

  primary_region            = true
  scylla_replication_factor = 3
  scylla_subnets            = module.unreal_cloud_ddc_vpc_region_1.private_subnet_ids
  scylla_ami_name           = "ScyllaDB 6.2.1"
  scylla_architecture       = "x86_64"
  scylla_instance_type      = "i4i.xlarge"
  existing_scylla_ips       = module.unreal_cloud_ddc_infra_region_2.scylla_ips

  scylla_db_throughput = 200
  scylla_db_storage    = 100

  monitoring_application_load_balancer_subnets = module.unreal_cloud_ddc_vpc_region_1.public_subnet_ids
  alb_certificate_arn                          = aws_acm_certificate.scylla_monitoring_region_1.arn

  nvme_managed_node_instance_type = "i3en.xlarge"
  nvme_managed_node_desired_size  = 2

  worker_managed_node_instance_type = "c6i.large"
  worker_managed_node_desired_size  = 1

  system_managed_node_instance_type = "m7i.large"
  system_managed_node_desired_size  = 1
}

# Security groups for cross region communication

resource "aws_vpc_security_group_ingress_rule" "scylla_db_region_1_to_2" {
  description       = "Allow communication between scyllaDB nodes across VPCs"
  region            = var.regions[0]
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "TCP"
  cidr_ipv4         = "192.168.128.0/17"
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
  cluster_endpoint                    = module.unreal_cloud_ddc_infra_region_1.cluster_endpoint
  cluster_version                     = module.unreal_cloud_ddc_infra_region_1.cluster_version
  cluster_oidc_provider_arn           = module.unreal_cloud_ddc_infra_region_1.oidc_provider_arn
  ghcr_credentials_secret_manager_arn = var.github_credential_arn_region_1
  s3_bucket_id                        = module.unreal_cloud_ddc_infra_region_1.s3_bucket_id


  unreal_cloud_ddc_helm_base_infra_chart  = "${path.module}/assets/unreal_cloud_ddc_multi_region_base.yaml"
  unreal_cloud_ddc_helm_replication_chart = "${path.module}/assets/unreal_cloud_ddc_multi_region.yaml"

  unreal_cloud_ddc_helm_config = {
    scylla_ips             = join(",", local.scylla_ips)
    bucket_name            = module.unreal_cloud_ddc_infra_region_1.s3_bucket_id
    region                 = substr(var.regions[0], length(var.regions[0]) - 1, 1) == "1" ? substr(var.regions[0], 0, length(var.regions[0]) - 2) : var.regions[0]
    replication_region     = substr(var.regions[1], length(var.regions[1]) - 1, 1) == "1" ? substr(var.regions[1], 0, length(var.regions[1]) - 2) : var.regions[0]
    aws_region             = var.regions[0]
    aws_replication_region = var.regions[1]
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

  primary_region                   = false
  scylla_replication_factor        = 3
  existing_scylla_seed             = module.unreal_cloud_ddc_infra_region_1.scylla_seed
  create_scylla_monitoring_stack   = false
  create_application_load_balancer = false
  scylla_subnets                   = module.unreal_cloud_ddc_vpc_region_2.private_subnet_ids
  scylla_ami_name                  = "ScyllaDB 6.2.1"
  scylla_architecture              = "x86_64"
  scylla_instance_type             = "i4i.xlarge"

  scylla_db_throughput = 200
  scylla_db_storage    = 100

  nvme_managed_node_instance_type = "i3en.xlarge"
  nvme_managed_node_desired_size  = 2

  worker_managed_node_instance_type = "c6i.large"
  worker_managed_node_desired_size  = 1

  system_managed_node_instance_type = "m7i.large"
  system_managed_node_desired_size  = 1
}

# cross region communication for scylla
resource "aws_vpc_security_group_ingress_rule" "scylla_db_region_2_to_1" {
  description       = "Allow communication between scyllaDB nodes across VPCs"
  region            = var.regions[1]
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "TCP"
  cidr_ipv4         = "192.168.0.0/17"
  security_group_id = module.unreal_cloud_ddc_infra_region_2.scylla_security_group
}

# # Cross region load balancing

resource "aws_vpc_security_group_ingress_rule" "unreal_cloud_ddc_cluster_region_1_to_lb_region_2" {
  description       = "Allow communication between unreal cloud ddc clusters via load balancers"
  region            = var.regions[0]
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "TCP"
  cidr_ipv4         = "192.168.128.0/17"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
}

resource "aws_vpc_security_group_ingress_rule" "unreal_cloud_ddc_cluster_region_1_to_lb_region_2_http" {
  description       = "Allow communication between unreal cloud ddc clusters via load balancers"
  region            = var.regions[0]
  from_port         = 80
  to_port           = 80
  ip_protocol       = "TCP"
  cidr_ipv4         = "192.168.128.0/17"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1.id
}


resource "aws_vpc_security_group_ingress_rule" "unreal_cloud_ddc_cluster_region_2_to_lb_region_1" {
  description       = "Allow communication between unreal cloud ddc clusters via load balancers"
  region            = var.regions[1]
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "TCP"
  cidr_ipv4         = "192.168.0.0/17"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
}

resource "aws_vpc_security_group_ingress_rule" "unreal_cloud_ddc_cluster_region_2_to_lb_region_1_http" {
  description       = "Allow communication between unreal cloud ddc clusters via load balancers"
  region            = var.regions[1]
  from_port         = 80
  to_port           = 80
  ip_protocol       = "TCP"
  cidr_ipv4         = "192.168.0.0/17"
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
  cluster_endpoint                    = module.unreal_cloud_ddc_infra_region_2.cluster_endpoint
  cluster_version                     = module.unreal_cloud_ddc_infra_region_2.cluster_version
  cluster_oidc_provider_arn           = module.unreal_cloud_ddc_infra_region_2.oidc_provider_arn
  ghcr_credentials_secret_manager_arn = var.github_credential_arn_region_2
  s3_bucket_id                        = module.unreal_cloud_ddc_infra_region_2.s3_bucket_id

  unreal_cloud_ddc_helm_base_infra_chart  = "${path.module}/assets/unreal_cloud_ddc_multi_region_base.yaml"
  unreal_cloud_ddc_helm_replication_chart = "${path.module}/assets/unreal_cloud_ddc_multi_region.yaml"

  unreal_cloud_ddc_helm_config = {
    scylla_ips             = join(",", local.scylla_ips)
    bucket_name            = module.unreal_cloud_ddc_infra_region_2.s3_bucket_id
    region                 = substr(var.regions[1], length(var.regions[1]) - 1, 1) == "1" ? substr(var.regions[1], 0, length(var.regions[1]) - 2) : var.regions[1]
    replication_region     = substr(var.regions[0], length(var.regions[0]) - 1, 1) == "1" ? substr(var.regions[0], 0, length(var.regions[0]) - 2) : var.regions[0]
    aws_region             = var.regions[1]
    aws_replication_region = var.regions[0]
    security_group_ids     = aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2.id
    token                  = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_2.secret_string
  }


  providers = {
    kubernetes = kubernetes.region-2,
    helm       = helm.region-2
    aws        = aws.region-2
  }
}
