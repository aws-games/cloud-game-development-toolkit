################################################################################
# VPC
################################################################################
module "unity_floating_license_server_vpc" {
  source                = "./vpc"
  vpc_cidr              = "192.168.0.0/16"
  private_subnets_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]
  public_subnets_cidrs  = ["192.168.2.0/24", "192.168.3.0/24"]
  availability_zones    = local.azs
  additional_tags       = local.tags
}

################################################################################
# S3 Bucket
################################################################################
module "unity_floating_license_bucket" {
  source = "./s3-bucket"
}

################################################################################
# Unity Floating License Server Module
################################################################################
module "unity_floating_license_server" {
  depends_on                          = [module.unity_floating_license_server_vpc]
  source                              = "../../modules/unity/unity-floating-license-server"
  vpc_id                              = module.unity_floating_license_server_vpc.vpc_id
  subnet_id                           = module.unity_floating_license_server_vpc.private_subnet_ids[0]
  eni_private_ips_list                = ["192.168.0.7"]
  unity_license_server_s3_bucket_name = module.unity_floating_license_bucket.s3_bucket_id
}

################################################################################
# Unity Client Module
################################################################################
module "unity_client_instance" {
  source    = "./unity-client"
  subnet_id = module.unity_floating_license_server_vpc.private_subnet_ids[0]
  vpc_id    = module.unity_floating_license_server_vpc.vpc_id
}

#allow ingress to unity floating license server from client
resource "aws_vpc_security_group_ingress_rule" "ingress_from_client_sg" {
  security_group_id            = module.unity_floating_license_server.unity_license_server_security_group_id
  description                  = "Ingress from Unity Client SG"
  ip_protocol                  = "tcp"
  from_port                    = module.unity_floating_license_server.unity_license_server_port
  to_port                      = module.unity_floating_license_server.unity_license_server_port
  referenced_security_group_id = module.unity_client_instance.unity_floating_license_client_sg
}
