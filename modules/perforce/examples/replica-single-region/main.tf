module "terraform-aws-perforce" {
  source = "../../"

  # - Shared -
  project_prefix = local.project_prefix
  vpc_id         = aws_vpc.perforce_vpc.id

  create_route53_private_hosted_zone = true
  route53_private_hosted_zone_name   = "${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"
  certificate_arn                    = local.certificate_arn
  existing_security_groups           = [aws_security_group.allow_my_ip.id]
  shared_alb_subnets                 = aws_subnet.private_subnets[*].id
  shared_nlb_subnets                 = aws_subnet.public_subnets[*].id

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

  # - P4 Server Replicas Configuration -
  p4_server_replicas_config = {
    standby-1b : {
      # Replica-specific
      replica_type = "standby"
      subdomain    = "standby"
      
      # General
      name                        = "p4-server-standby"
      project_prefix              = local.project_prefix
      environment                 = "dev"
      fully_qualified_domain_name = "standby.${local.p4_server_fully_qualified_domain_name}"

      # Compute
      lookup_existing_ami   = false
      instance_type         = "c6i.large"
      instance_architecture = "x86_64"
      p4_server_type        = "p4d_replica"
      unicode               = false
      selinux               = false
      case_sensitive        = true
      plaintext             = false

      # Storage
      storage_type         = "EBS"
      depot_volume_size    = 128
      metadata_volume_size = 32
      logs_volume_size     = 32

      # Networking & Security
      vpc_id                   = aws_vpc.perforce_vpc.id
      instance_subnet_id       = aws_subnet.public_subnets[1].id
      create_default_sg        = true
      existing_security_groups = [aws_security_group.allow_my_ip.id]
      internal                 = false
      
    },
    readonly-1c : {
      # Replica-specific
      replica_type = "readonly"
      subdomain    = "ci"
      
      # General
      name                        = "p4-server-ci"
      project_prefix              = local.project_prefix
      environment                 = "dev"
      fully_qualified_domain_name = "ci.${local.p4_server_fully_qualified_domain_name}"

      # Compute
      lookup_existing_ami   = false
      instance_type         = "c6i.large"
      instance_architecture = "x86_64"
      p4_server_type        = "p4d_replica"
      unicode               = false
      selinux               = false
      case_sensitive        = true
      plaintext             = false

      # Storage
      storage_type         = "EBS"
      depot_volume_size    = 128
      metadata_volume_size = 32
      logs_volume_size     = 32

      # Networking & Security
      vpc_id                   = aws_vpc.perforce_vpc.id
      instance_subnet_id       = aws_subnet.public_subnets[2].id
      create_default_sg        = true
      existing_security_groups = [aws_security_group.allow_my_ip.id]
      internal                 = false
    }
  }

  # - P4Auth Configuration -
  p4_auth_config = {
    # General
    name                        = "p4-auth"
    fully_qualified_domain_name = local.p4_auth_fully_qualified_domain_name
    existing_security_groups    = [aws_security_group.allow_my_ip.id]
    debug                       = true
    deregistration_delay        = 0
    service_subnets             = aws_subnet.private_subnets[*].id
  }

  # - P4 Code Review Configuration -
  p4_code_review_config = {
    name                        = "p4-code-review"
    fully_qualified_domain_name = local.p4_code_review_fully_qualified_domain_name
    existing_security_groups    = [aws_security_group.allow_my_ip.id]
    debug                       = true
    deregistration_delay        = 0
    service_subnets             = aws_subnet.private_subnets[*].id
    enable_sso                  = true
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