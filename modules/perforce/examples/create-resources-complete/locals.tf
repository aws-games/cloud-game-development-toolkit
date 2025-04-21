data "aws_availability_zones" "available" {}

locals {
  project_prefix = "cgd"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)

  # Domain name
  fully_qualified_domain_name = "Replace with your domain" # Ensure this domain already exists and is hosted using Amazon Route53 (has a public hosted zone in your target AWS account).

  # Subdomains
  perforce_subdomain       = "perforce"
  p4_auth_subdomain        = "auth"
  p4_code_review_subdomain = "review"

  # P4 Server Domain
  p4_server_fully_qualified_domain_name = "${local.perforce_subdomain}.${local.fully_qualified_domain_name}"

  # P4Auth Domain
  p4_auth_fully_qualified_domain_name = "${local.p4_auth_subdomain}.${local.perforce_subdomain}.${local.fully_qualified_domain_name}"

  # P4 Code Review
  p4_code_review_fully_qualified_domain_name = "${local.p4_code_review_subdomain}.${local.perforce_subdomain}.${local.fully_qualified_domain_name}"


  # Amazon Certificate Manager (ACM)
  certificate_arn               = aws_acm_certificate.perforce.arn


  # VPC Configuration
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

  tags = {
    environment = "dev"
  }
}
