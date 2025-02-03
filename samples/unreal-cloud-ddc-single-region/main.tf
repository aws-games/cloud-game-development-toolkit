resource "awscc_secretsmanager_secret" "unreal_cloud_ddc_token" {
  name        = "unreal-cloud-ddc-token"
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

################################################################################
# Single Region with Token
################################################################################

module "unreal_cloud_ddc_infra" {
  depends_on = [module.unreal_cloud_ddc_vpc]
  source     = "../../modules/unreal/unreal-cloud-ddc-infra"
  name       = "unreal-cloud-ddc"
  vpc_id     = module.unreal_cloud_ddc_vpc.vpc_id

  eks_node_group_subnets                  = module.unreal_cloud_ddc_vpc.private_subnet_ids
  eks_cluster_public_endpoint_access_cidr = var.eks_cluster_ip_allow_list != null ? var.eks_cluster_ip_allow_list : [chomp("${data.http.public_ip.response_body}/32")]
  eks_cluster_private_access              = true
  eks_cluster_public_access               = true

  scylla_subnets       = module.unreal_cloud_ddc_vpc.private_subnet_ids
  scylla_ami_name      = "ScyllaDB 6.2.1"
  scylla_architecture  = "x86_64"
  scylla_instance_type = "i4i.xlarge"

  scylla_db_throughput = 200
  scylla_db_storage    = 100

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

  source                              = "../../modules/unreal/unreal-cloud-ddc-intra-cluster"
  cluster_name                        = module.unreal_cloud_ddc_infra.cluster_name
  cluster_oidc_provider_arn           = module.unreal_cloud_ddc_infra.oidc_provider_arn
  ghcr_credentials_secret_manager_arn = var.github_credential_arn

  s3_bucket_id = module.unreal_cloud_ddc_infra.s3_bucket_id

  unreal_cloud_ddc_helm_values = [
    templatefile("${path.module}/assets/unreal_cloud_ddc_single_region.yaml", {
      scylla_ips  = "${module.unreal_cloud_ddc_infra.scylla_ips[0]},${module.unreal_cloud_ddc_infra.scylla_ips[1]}"
      bucket_name = module.unreal_cloud_ddc_infra.s3_bucket_id
      region      = data.aws_region.current.name
      token       = data.aws_secretsmanager_secret_version.unreal_cloud_ddc_token.secret_string
    })
  ]
}
