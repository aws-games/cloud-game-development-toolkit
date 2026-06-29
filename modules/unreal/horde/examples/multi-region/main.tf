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
  p4_port                           = ""
  agents                            = {}

  depends_on = [aws_acm_certificate_validation.horde]
}
