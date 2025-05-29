data "aws_secretsmanager_random_password" "unreal_ddc" {
  password_length     = 64
  include_space       = false
  exclude_punctuation = true
  exclude_numbers     = false
}
resource "aws_secretsmanager_secret" "unreal_cloud_ddc_token" {
  name        = "unreal-cloud-ddc-bearer-token-multi-region"
  description = "The token to access unreal cloud ddc sample."
  region      = "us-west-2"
  replica {
    region = "us-east-2"
  }
  #checkov:skip=CKV_AWS_149: KMS encryption not yet
  #checkov:skip=CKV2_AWS_57: Secret rotation is not required for this sample.
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "unreal_ddc" {
  secret_id     = aws_secretsmanager_secret.unreal_cloud_ddc_token.id
  secret_string = data.aws_secretsmanager_random_password.unreal_ddc.random_password
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token_us_west_2" {
  region    = "us-west-2"
  secret_id = aws_secretsmanager_secret_version.unreal_ddc.secret_id
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token_us_east_2" {
  region    = "us-east-2"
  secret_id = aws_secretsmanager_secret_version.unreal_ddc.secret_id
}

data "http" "public_ip" {
  url = "https://checkip.amazonaws.com/"
}

################################################################################
# VPC
################################################################################

# us-west-2 VPC and security group

module "unreal_cloud_ddc_vpc_us_west_2" {
  source                = "./vpc"
  vpc_cidr              = "192.168.0.0/17"
  private_subnets_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]
  public_subnets_cidrs  = ["192.168.2.0/24", "192.168.3.0/24"]
  region                = "us-west-2"
  availability_zones    = local.azs_us_west_2
  additional_tags       = local.tags
}

resource "aws_security_group" "unreal_ddc_load_balancer_access_security_group_us_west_2" {
  depends_on  = [module.unreal_cloud_ddc_vpc_us_west_2]
  region      = "us-west-2"
  name        = "cgd-load-balancer-sg"
  description = "Access unreal ddc load balancer"
  vpc_id      = module.unreal_cloud_ddc_vpc_us_west_2.vpc_id

  tags = local.tags
  #checkov:skip=CKV2_AWS_5: Security group is passed as a variable by design in this example
}


resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_http_ingress_rule_us_west_2" {
  count             = var.allow_my_ip ? 1 : 0
  region            = "us-west-2"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_us_west_2.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_https_ingress_rule_us_west_2" {
  count             = var.allow_my_ip ? 1 : 0
  region            = "us-west-2"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_us_west_2.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_egress_rule" "unreal_ddc_load_balancer_egress_sg_rules_us_west_2" {
  region            = "us-west-2"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_us_west_2.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# us-east-2 VPC and security group

module "unreal_cloud_ddc_vpc_us_east_2" {
  source                = "./vpc"
  vpc_cidr              = "192.168.128.0/17"
  private_subnets_cidrs = ["192.168.128.0/24", "192.168.129.0/24"]
  public_subnets_cidrs  = ["192.168.130.0/24", "192.168.131.0/24"]
  region                = "us-east-2"
  availability_zones    = local.azs_us_east_2
  additional_tags       = local.tags
}

resource "aws_security_group" "unreal_ddc_load_balancer_access_security_group_us_east_2" {
  depends_on  = [module.unreal_cloud_ddc_vpc_us_east_2]
  region      = "us-east-2"
  name        = "cgd-load-balancer-sg"
  description = "Access unreal ddc load balancer"
  vpc_id      = module.unreal_cloud_ddc_vpc_us_east_2.vpc_id

  tags = local.tags
  #checkov:skip=CKV2_AWS_5: Security group is passed as a variable by design in this example
}


resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_http_ingress_rule_us_east_2" {
  count             = var.allow_my_ip ? 1 : 0
  region            = "us-east-2"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_us_east_2.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_https_ingress_rule_us_east_2" {
  count             = var.allow_my_ip ? 1 : 0
  region            = "us-east-2"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_us_east_2.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_egress_rule" "unreal_ddc_load_balancer_egress_sg_rules_us_east_2" {
  region            = "us-east-2"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group_us_east_2.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Multi Region with Token
################################################################################

# us-west-2 resources

module "unreal_cloud_ddc_infra_us_west_2" {
  depends_on = [module.unreal_cloud_ddc_vpc_us_west_2]
  source     = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra"
  name       = "unreal-cloud-ddc"
  vpc_id     = module.unreal_cloud_ddc_vpc_us_west_2.vpc_id
  region     = "us-west-2"

  eks_node_group_subnets                  = module.unreal_cloud_ddc_vpc_us_west_2.private_subnet_ids
  eks_cluster_public_endpoint_access_cidr = ["${chomp(data.http.public_ip.response_body)}/32"]
  eks_cluster_private_access              = true
  eks_cluster_public_access               = true
  existing_security_groups                = var.allow_my_ip ? local.existing_security_groups_us_west_2 : []

  scylla_subnets       = module.unreal_cloud_ddc_vpc_us_west_2.private_subnet_ids
  scylla_ami_name      = "ScyllaDB 6.2.1"
  scylla_architecture  = "x86_64"
  scylla_instance_type = "i4i.xlarge"

  scylla_db_throughput = 200
  scylla_db_storage    = 100

  monitoring_application_load_balancer_subnets = module.unreal_cloud_ddc_vpc_us_west_2.public_subnet_ids
  alb_certificate_arn                          = aws_acm_certificate.scylla_monitoring_us_west_2.arn

  nvme_managed_node_instance_type = "i3en.xlarge"
  nvme_managed_node_desired_size  = 2

  worker_managed_node_instance_type = "c6i.large"
  worker_managed_node_desired_size  = 1

  system_managed_node_instance_type = "m7i.large"
  system_managed_node_desired_size  = 1

  providers = {
    kubernetes = kubernetes.us-west-2,
    helm       = helm.us-west-2
  }
}

module "unreal_cloud_ddc_intra_cluster_us_west_2" {
  depends_on = [
    module.unreal_cloud_ddc_infra_us_west_2,
    module.unreal_cloud_ddc_infra_us_west_2.oidc_provider_arn
  ]

  source                              = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster"
  region                              = "us-west-2"
  cluster_name                        = module.unreal_cloud_ddc_infra_us_west_2.cluster_name
  cluster_oidc_provider_arn           = module.unreal_cloud_ddc_infra_us_west_2.oidc_provider_arn
  ghcr_credentials_secret_manager_arn = var.github_credential_arn

  s3_bucket_id = module.unreal_cloud_ddc_infra_us_west_2.s3_bucket_id

  unreal_cloud_ddc_helm_values = [
    templatefile("${path.module}/assets/unreal_cloud_ddc_single_region.yaml", {
      scylla_ips         = "${module.unreal_cloud_ddc_infra_us_west_2.scylla_ips[0]},${module.unreal_cloud_ddc_infra_us_west_2.scylla_ips[1]}"
      bucket_name        = module.unreal_cloud_ddc_infra_us_west_2.s3_bucket_id
      region             = data.aws_region.us_west_2.region
      security_group_ids = join(",", local.existing_security_groups_us_west_2)
      # replace the region value with the line below if deploying this in any AWS region ending in -1
      #region = substr(data.aws_region.current.name, 0, length(data.aws_region.current.name) - 2)
      token = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token_us_west_2.secret_string
    })
  ]
  providers = {
    kubernetes = kubernetes.us-west-2,
    helm       = helm.us-west-2
  }
}

# us-east-2 resources

module "unreal_cloud_ddc_infra_us_east_2" {
  depends_on = [module.unreal_cloud_ddc_vpc_us_east_2]
  source     = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra"
  name       = "unreal-cloud-ddc"
  vpc_id     = module.unreal_cloud_ddc_vpc_us_east_2.vpc_id
  region     = "us-east-2"

  eks_node_group_subnets                  = module.unreal_cloud_ddc_vpc_us_east_2.private_subnet_ids
  eks_cluster_public_endpoint_access_cidr = ["${chomp(data.http.public_ip.response_body)}/32"]
  eks_cluster_private_access              = true
  eks_cluster_public_access               = true
  existing_security_groups                = var.allow_my_ip ? local.existing_security_groups_us_east_2 : []

  scylla_subnets       = module.unreal_cloud_ddc_vpc_us_east_2.private_subnet_ids
  scylla_ami_name      = "ScyllaDB 6.2.1"
  scylla_architecture  = "x86_64"
  scylla_instance_type = "i4i.xlarge"

  scylla_db_throughput = 200
  scylla_db_storage    = 100

  monitoring_application_load_balancer_subnets = module.unreal_cloud_ddc_vpc_us_east_2.public_subnet_ids
  alb_certificate_arn                          = aws_acm_certificate.scylla_monitoring_us_east_2.arn

  nvme_managed_node_instance_type = "i3en.xlarge"
  nvme_managed_node_desired_size  = 2

  worker_managed_node_instance_type = "c6i.large"
  worker_managed_node_desired_size  = 1

  system_managed_node_instance_type = "m7i.large"
  system_managed_node_desired_size  = 1

  providers = {
    kubernetes = kubernetes.us-east-2,
    helm       = helm.us-east-2
  }
}

module "unreal_cloud_ddc_intra_cluster_us_east_2" {
  depends_on = [
    module.unreal_cloud_ddc_infra_us_east_2,
    module.unreal_cloud_ddc_infra_us_east_2.oidc_provider_arn
  ]

  source                              = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster"
  region                              = "us-east-2"
  cluster_name                        = module.unreal_cloud_ddc_infra_us_east_2.cluster_name
  cluster_oidc_provider_arn           = module.unreal_cloud_ddc_infra_us_east_2.oidc_provider_arn
  ghcr_credentials_secret_manager_arn = var.github_credential_arn

  s3_bucket_id = module.unreal_cloud_ddc_infra_us_east_2.s3_bucket_id

  unreal_cloud_ddc_helm_values = [
    templatefile("${path.module}/assets/unreal_cloud_ddc_single_region.yaml", {
      scylla_ips         = "${module.unreal_cloud_ddc_infra_us_east_2.scylla_ips[0]},${module.unreal_cloud_ddc_infra_us_east_2.scylla_ips[1]}"
      bucket_name        = module.unreal_cloud_ddc_infra_us_east_2.s3_bucket_id
      region             = data.aws_region.us_east_2.region
      security_group_ids = join(",", local.existing_security_groups_us_east_2)
      # replace the region value with the line below if deploying this in any AWS region ending in -1
      #region = substr(data.aws_region.current.name, 0, length(data.aws_region.current.name) - 2)
      token = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token_us_east_2.secret_string
    })
  ]
  providers = {
    kubernetes = kubernetes.us-east-2,
    helm       = helm.us-east-2
  }
}
