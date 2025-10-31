##################################################
# Data Sources
##################################################

data "aws_availability_zones" "available" {}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

##################################################
# Local Variables
##################################################

locals {
  # Project Configuration
  project_prefix = "ubp"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  my_ip          = chomp(data.http.my_ip.response_body)

  # Subdomain Configuration
  # All services will be accessible at: <subdomain>.<route53_public_hosted_zone_name>
  perforce_subdomain          = "perforce"
  p4_swarm_subdomain          = "swarm"
  teamcity_subdomain          = "teamcity"
  unity_accelerator_subdomain = "unity-accelerator"
  unity_license_subdomain     = "unity-license"

  # Fully Qualified Domain Names
  perforce_fqdn          = "${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"
  p4_swarm_fqdn          = "${local.p4_swarm_subdomain}.${var.route53_public_hosted_zone_name}"
  teamcity_fqdn          = "${local.teamcity_subdomain}.${var.route53_public_hosted_zone_name}"
  unity_accelerator_fqdn = "${local.unity_accelerator_subdomain}.${var.route53_public_hosted_zone_name}"
  unity_license_fqdn     = "${local.unity_license_subdomain}.${var.route53_public_hosted_zone_name}"

  ##################################################
  # VPC & Networking Configuration
  ##################################################

  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

  ##################################################
  # Tags
  ##################################################

  tags = {
    Project   = "unity-build-pipeline"
    ManagedBy = "terraform"
  }
}
