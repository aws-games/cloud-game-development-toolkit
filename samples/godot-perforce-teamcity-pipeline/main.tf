// teamcity module
module "teamcity" {
  source = "../../modules/teamcity"
  vpc_id                      = aws_vpc.sample_vpc.id
  service_subnets             = aws_subnet.private_subnets[*].id
  alb_subnets                 = aws_subnet.public_subnets[*].id
  alb_certificate_arn         = aws_acm_certificate.teamcity.arn
  debug = true
  // not sure if this needs to be created... but teamcity main module does not have dns
  # route53_private_hosted_zone_name  = "teamcity.${var.route53_public_hosted_zone_name}"
}


module perforce {
  source = "../../modules/perforce"
  // disable shared
  vpc_id                      = aws_vpc.sample_vpc.id
  create_route53_private_hosted_zone = true
  route53_private_hosted_zone_name   = "perforce.${var.route53_public_hosted_zone_name}"
  create_shared_network_load_balancer = false
  create_shared_application_load_balancer = false


  p4_server_config = {
    # fully_qualified_domain_name = "perforce.${var.route53_public_hosted_zone_name}"
    name                        = "p4-server"
    fully_qualified_domain_name = "perforce.${var.route53_public_hosted_zone_name}"

    p4_server_type = "p4d_commit"

    depot_volume_size    = 128
    metadata_volume_size = 32
    logs_volume_size     = 32

    // not quite understanding this one
    instance_subnet_id       = aws_subnet.public_subnets[0].id
  }
}

# placeholder since provider is "required" by the module
provider "netapp-ontap" {
  connection_profiles = [
    {
      name     = "null"
      hostname = "null"
      username = "null"
      password = "null"
    }
  ]
}

