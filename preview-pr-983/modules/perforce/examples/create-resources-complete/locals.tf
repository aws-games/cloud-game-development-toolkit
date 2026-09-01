data "aws_availability_zones" "available" {}

locals {
  project_prefix = "cgd"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)

  # Subdomains
  perforce_subdomain       = "perforce"
  p4_auth_subdomain        = "auth"
  p4_code_review_subdomain = "review"

  # P4 Server Domain
  p4_server_fully_qualified_domain_name = "${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"

  # P4Auth Domain
  p4_auth_fully_qualified_domain_name = "${local.p4_auth_subdomain}.${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"

  # P4 Code Review
  p4_code_review_fully_qualified_domain_name = "${local.p4_code_review_subdomain}.${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"


  # Amazon Certificate Manager (ACM)
  certificate_arn = aws_acm_certificate.perforce.arn


  # VPC Configuration
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

  tags = {
    environment = "dev"
  }
}
