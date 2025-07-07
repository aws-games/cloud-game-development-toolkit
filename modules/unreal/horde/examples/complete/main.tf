data "aws_availability_zones" "available" {}

locals {
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  azs                  = slice(data.aws_availability_zones.available.names, 0, 2)
  tags                 = {}
}

module "unreal_engine_horde" {
  source                            = "../../"
  unreal_horde_service_subnets      = aws_subnet.private_subnets[*].id
  unreal_horde_external_alb_subnets = aws_subnet.public_subnets[*].id  # External ALB used by developers
  unreal_horde_internal_alb_subnets = aws_subnet.private_subnets[*].id # Internal ALB used by agents
  vpc_id                            = aws_vpc.unreal_engine_horde_vpc.id
  certificate_arn                   = aws_acm_certificate.unreal_engine_horde.arn
  github_credentials_secret_arn     = var.github_credentials_secret_arn
  tags                              = local.tags
  elasticache_engine                = "valkey"
  agents = {
    ubuntu-x86 = {
      ami           = data.aws_ami.ubuntu_noble_amd.id
      instance_type = "c7a.large"
      min_size      = 2
      max_size      = 5
      block_device_mappings = [
        {
          device_name = "/dev/sda1"
          ebs = {
            volume_size = 64
          }
        }
      ]
    }
  }

  fully_qualified_domain_name = "horde.${var.root_domain_name}"

  depends_on = [aws_acm_certificate_validation.unreal_engine_horde]
}
