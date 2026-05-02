data "aws_availability_zones" "available" {}

data "aws_ami" "ubuntu_noble_amd" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name = "architecture"
    values = [
      "x86_64"
    ]
  }

  owners = ["amazon"]
}


locals {
  project_prefix = "cgd"
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)

  # Subdomains
  perforce_subdomain       = "perforce"
  p4_auth_subdomain        = "auth"
  p4_code_review_subdomain = "review"
  jenkins_subdomain        = "jenkins"

  # P4 Server Domain
  p4_server_fully_qualified_domain_name = "${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"

  # P4Auth Domain
  p4_auth_fully_qualified_domain_name = "${local.p4_auth_subdomain}.${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"

  # P4 Code Review
  p4_code_review_fully_qualified_domain_name = "${local.p4_code_review_subdomain}.${local.perforce_subdomain}.${var.route53_public_hosted_zone_name}"

  # Jenkins Domain
  jenkins_fully_qualified_domain_name = "${local.jenkins_subdomain}.${var.route53_public_hosted_zone_name}"

  # Jenkins and Build Farm Configurations
  jenkins_agent_secret_arns = []

  build_farm_compute = {
    ubuntu_builders : {
      ami           = data.aws_ami.ubuntu_noble_amd.image_id
      instance_type = "t3a.small"
    }
  }

  build_farm_fsx_openzfs_storage = {
    /* Example Configuration
    cache : {
      storage_type        = "SSD"
      throughput_capacity = 160
      storage_capacity    = 256
      deployment_type     = "MULTI_AZ_1"
      route_table_ids     = [aws_route_table.private_rt.id]
    }
    workspace : {
      storage_type        = "SSD"
      throughput_capacity = 160
      storage_capacity    = 564
      deployment_type     = "MULTI_AZ_1"
      route_table_ids     = [aws_route_table.private_rt.id]
    }
    */
  }

  # VPC Configuration
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

  tags = {
    environment = "dev"
  }
}
