provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "eu-west-1"
}

module "horde" {
  source = "../../"

  unreal_horde_service_subnets      = aws_subnet.private[*].id
  unreal_horde_external_alb_subnets = aws_subnet.public[*].id
  unreal_horde_internal_alb_subnets = aws_subnet.private[*].id
  vpc_id                            = aws_vpc.primary.id
  certificate_arn                   = aws_acm_certificate.horde.arn
  fully_qualified_domain_name       = "horde.${var.root_domain_name}"
  image                             = var.image
  tags                              = local.tags
  elasticache_engine                = "valkey"
  auth_method                       = "Anonymous"
  enable_new_agents_by_default      = true
  p4_port                           = ""
  agents = var.enable_agents ? {
    linux-x86 = {
      ami           = data.aws_ami.ubuntu.id
      instance_type = "c6a.large"
      min_size      = 0
      max_size      = 2
      block_device_mappings = [{
        device_name = "/dev/sda1"
        ebs = { volume_size = 64 }
      }]
    }
  } : {}

  extra_environment = [
    {
      name  = "Horde__http2Port"
      value = "0"
    },
    {
      name  = "Horde__serverUrl"
      value = "https://horde.${var.root_domain_name}"
    },
    {
      name  = "Horde__forceConfigUpdateOnStartup"
      value = "true"
    },
    {
      name  = "Horde__Compute__WithAws"
      value = "true"
    },
    {
      name  = "Horde__Plugins__Tools__Tools__0__Id"
      value = "horde-agent"
    },
    {
      name  = "Horde__Plugins__Tools__Tools__0__Name"
      value = "Horde Agent"
    },
    {
      name  = "Horde__Plugins__Tools__Tools__0__Public"
      value = "true"
    },
  ]

  depends_on = [aws_acm_certificate_validation.horde]
}
