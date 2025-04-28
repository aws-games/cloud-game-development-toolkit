resource "awscc_secretsmanager_secret" "unreal_cloud_ddc_token" {
  name        = "unreal-cloud-ddc-bearer-token"
  description = "The token to access unreal cloud ddc sample."
  generate_secret_string = {
    exclude_punctuation = true
    exclude_numbers     = false
    include_space       = false
    password_length     = 64
  }
}

data "aws_secretsmanager_secret_version" "unreal_cloud_ddc_token" {
  secret_id = awscc_secretsmanager_secret.unreal_cloud_ddc_token.id
}

data "http" "public_ip" {
  url = "https://checkip.amazonaws.com/"
}

################################################################################
# VPC
################################################################################

module "unreal_cloud_ddc_vpc" {
  source                = "./vpc"
  vpc_cidr              = "192.168.0.0/16"
  private_subnets_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]
  public_subnets_cidrs  = ["192.168.2.0/24", "192.168.3.0/24"]
  availability_zones    = local.azs
  additional_tags       = local.tags
}

resource "aws_security_group" "unreal_ddc_load_balancer_access_security_group" {
  name        = "cgd-load-balancer-sg"
  description = "Access unreal ddc load balancer"
  vpc_id      = module.unreal_cloud_ddc_vpc.vpc_id

  tags = local.tags
}


resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_http_ingress_rule" {
  count             = var.allow_my_ip ? 1 : 0
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_http2_ingress_rule" {
  count             = var.allow_my_ip ? 1 : 0
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_ddc_load_balancer_https_ingress_rule" {
  count             = var.allow_my_ip ? 1 : 0
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.public_ip.response_body)}/32"
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group.id
  description       = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

resource "aws_vpc_security_group_egress_rule" "unreal_ddc_load_balancer_egress_sg_rules" {
  security_group_id = aws_security_group.unreal_ddc_load_balancer_access_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Single Region with Token
################################################################################

module "unreal_cloud_ddc_infra" {
  depends_on = [module.unreal_cloud_ddc_vpc]
  source     = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra"
  name       = "unreal-cloud-ddc"
  region     = data.aws_region.current.name
  vpc_id     = module.unreal_cloud_ddc_vpc.vpc_id

  eks_node_group_subnets                  = module.unreal_cloud_ddc_vpc.private_subnet_ids
  eks_cluster_public_endpoint_access_cidr = ["${chomp(data.http.public_ip.response_body)}/32"]
  eks_cluster_private_access              = true
  eks_cluster_public_access               = true
  existing_security_groups                = [aws_security_group.unreal_ddc_load_balancer_access_security_group.id]

  scylla_subnets       = module.unreal_cloud_ddc_vpc.private_subnet_ids
  scylla_ami_name      = "ScyllaDB 6.2.1"
  scylla_architecture  = "x86_64"
  scylla_instance_type = "i4i.xlarge"

  scylla_db_throughput = 200
  scylla_db_storage    = 100

  monitoring_application_load_balancer_subnets = module.unreal_cloud_ddc_vpc.public_subnet_ids
  alb_certificate_arn                          = aws_acm_certificate.scylla_monitoring.arn

  nvme_managed_node_instance_type = "i3en.xlarge"
  nvme_managed_node_desired_size  = 2

  worker_managed_node_instance_type = "c6i.large"
  worker_managed_node_desired_size  = 1

  system_managed_node_instance_type = "m7i.large"
  system_managed_node_desired_size  = 1
}

module "unreal_cloud_ddc_intra_cluster" {
  depends_on = [
    module.unreal_cloud_ddc_infra,
    module.unreal_cloud_ddc_infra.oidc_provider_arn
  ]

  source                              = "../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster"
  cluster_name                        = module.unreal_cloud_ddc_infra.cluster_name
  cluster_oidc_provider_arn           = module.unreal_cloud_ddc_infra.oidc_provider_arn
  ghcr_credentials_secret_manager_arn = var.github_credential_arn

  s3_bucket_id = module.unreal_cloud_ddc_infra.s3_bucket_id

  unreal_cloud_ddc_helm_values = [
    templatefile("${path.module}/assets/unreal_cloud_ddc_single_region.yaml", {
      scylla_ips         = "${module.unreal_cloud_ddc_infra.scylla_ips[0]},${module.unreal_cloud_ddc_infra.scylla_ips[1]}"
      bucket_name        = module.unreal_cloud_ddc_infra.s3_bucket_id
      region             = substr(data.aws_region.current.name, length(data.aws_region.current.name) - 1, 1) == "1" ? substr(data.aws_region.current.name, 0, length(data.aws_region.current.name) - 2) : data.aws_region.current.name
      aws_region         = data.aws_region.current.name
      security_group_ids = aws_security_group.unreal_ddc_load_balancer_access_security_group.id
      token              = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token.secret_string
    })
  ]
}
