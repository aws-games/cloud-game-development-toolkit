data "aws_secretsmanager_secret" "oidc_secrets" {
  arn = var.oidc_credential_arn
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.oidc_secrets.id
}


module "unreal_cloud_ddc_vpc" {
  source                = "./vpc"
  vpc_cidr              = "192.168.0.0/23"
  private_subnets_cidrs = ["192.168.0.0/25", "192.168.0.128/25"]
  public_subnets_cidrs  = ["192.168.1.0/25", "192.168.1.128/25"]
  availability_zones    = local.azs
  additional_tags       = local.tags
}

################################################################################
# Single Region
################################################################################

module "unreal_cloud_ddc_infra" {
  depends_on              = [module.unreal_cloud_ddc_vpc]
  source                  = "../../modules/unreal/unreal-cloud-ddc-infra"
  name                    = "unreal-cloud-ddc"
  vpc_id                  = module.unreal_cloud_ddc_vpc.vpc_id
  private_subnets         = module.unreal_cloud_ddc_vpc.private_subnet_ids
  eks_cluster_access_cidr = var.eks_cluster_ip_allow_list

  scylla_private_subnets = module.unreal_cloud_ddc_vpc.private_subnet_ids
  scylla_ami_name        = "ScyllaDB 6.2.1"
  scylla_architecture    = "x86_64"
  scylla_instance_type   = "i4i.xlarge"

  scylla_db_throughput = 200
  scylla_db_storage    = 100

  nvme_managed_node_instance_type = "i3en.xlarge"
  nvme_managed_node_desired_size  = 2

  worker_managed_node_instance_type = "c5.xlarge"
  worker_managed_node_desired_size  = 0

  system_managed_node_instance_type = "m5.large"
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
  gchr_credentials_secret_manager_arn = var.github_credential_arn
  oidc_credentials_secret_manager_arn = var.oidc_credential_arn

  s3_bucket_id = module.unreal_cloud_ddc_infra.s3_bucket_id

  unreal_cloud_ddc_helm_values = [
    templatefile("./assets/unreal_cloud_ddc_region_values.yaml", {
      region      = data.aws_region.current.name
      bucket_name = module.unreal_cloud_ddc_infra.s3_bucket_id
    }),
    templatefile("./assets/unreal_cloud_ddc_base.yaml", {
      scylla_ips          = "${module.unreal_cloud_ddc_infra.scylla_ips[0]},${module.unreal_cloud_ddc_infra.scylla_ips[1]}"
      region              = data.aws_region.current.name
      okta_domain         = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["okta_domain"]
      okta_auth_server_id = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["okta_auth_server_id"]
      jwt_audience        = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["jwt_audience"]
      jwt_authority       = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)["jwt_authority"]
    }),
    file("./assets/unreal_cloud_ddc_values.yaml")
  ]
}
