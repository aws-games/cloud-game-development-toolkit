module "terraform-aws-perforce" {
  source = "../../"
  # source = "aws-games/perforce/aws" # remote example
  # version = "v1.0.0"

  # - Shared -
  project_prefix       = local.project_prefix
  vpc_id               = aws_vpc.perforce_vpc.id
  public_subnets       = aws_subnet.public_subnets[*].id
  public_subnets_cidrs = local.public_subnet_cidrs
  private_subnets      = aws_subnet.private_subnets[*].id

  create_route53_private_hosted_zone = true
  route53_private_hosted_zone_name   = local.fully_qualified_domain_name
  certificate_arn                    = local.certificate_arn
  existing_security_groups           = [aws_security_group.allow_my_ip.id]

  # - P4 Server Configuration -
  p4_server_config = {
    # General
    name                        = "p4-server"
    fully_qualified_domain_name = local.p4_server_fully_qualified_domain_name

    # Compute
    lookup_existing_ami      = false
    enable_auto_ami_creation = true
    p4_server_type           = "p4d_commit"

    # Storage
    depot_volume_size    = 128
    metadata_volume_size = 32
    logs_volume_size     = 32

    # Networking & Security
    instance_subnet_id       = aws_subnet.public_subnets[0].id
    existing_security_groups = [aws_security_group.allow_my_ip.id]
  }

  # - P4Auth Configuration -
  p4_auth_config = {
    # General
    name                        = "p4-auth"
    fully_qualified_domain_name = local.p4_auth_fully_qualified_domain_name
    existing_security_groups    = [aws_security_group.allow_my_ip.id]
    debug                       = true # optional to use for debugging. Default is false if omitted
    deregistration_delay        = 0
  }


  # - P4 Code Review Configuration -
  p4_code_review_config = {
    name                        = "p4-code-review"
    fully_qualified_domain_name = local.p4_code_review_fully_qualified_domain_name
    existing_security_groups    = [aws_security_group.allow_my_ip.id]
    debug                       = true # optional to use for debugging. Default is false if omitted
    deregistration_delay        = 0

    # Configuration
    enable_sso = true

  }

}
