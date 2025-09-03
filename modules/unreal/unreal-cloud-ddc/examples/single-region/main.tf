module "unreal_cloud_ddc" {
  source = "../../"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }


  # - Shared -
  region = local.primary_region
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  public_subnets = aws_subnet.public_subnets[*].id
  private_subnets = aws_subnet.private_subnets[*].id
  existing_security_groups = [aws_security_group.allow_my_ip.id]

  # DNS Configuration
  route53_public_hosted_zone_name = var.route53_public_hosted_zone_name
  certificate_arn = aws_acm_certificate.ddc.arn

  # - DDC Infra Configuration -
  ddc_infra_config = {
    region = local.primary_region
    eks_node_group_subnets = aws_subnet.private_subnets[*].id
    eks_api_access_cidrs   = ["${chomp(data.http.my_ip.response_body)}/32"]
    scylla_subnets = aws_subnet.private_subnets[*].id
  }

  # - DDC Services Configuration -
  ddc_services_config = {
    region = local.primary_region
    ghcr_credentials_secret_manager_arn = var.ghcr_credentials_secret_manager_arn
  }
}
