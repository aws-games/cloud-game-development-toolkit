locals {
  tags = merge(
    {
      "ENVIRONMENT" = var.environment
    },
    var.tags,
  )
}

resource "aws_security_group" "helix_core" {
  vpc_id      = var.vpc_id
  name        = "helix-core-sg"
  description = "Security group for Helix Core machines."
  tags        = local.tags
}

resource "aws_vpc_security_group_egress_rule" "helix_core_internet" {
  security_group_id = aws_security_group.helix_core.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
  description       = "Helix Core out to Internet"
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_self_p4" {
  security_group_id            = aws_security_group.helix_core.id
  from_port                    = 1666
  ip_protocol                  = "tcp"
  to_port                      = 1666
  referenced_security_group_id = aws_security_group.helix_core.id
  description                  = "Helix Core to Helix Core"
}

module "helix_core" {
  source                   = "./helix-core"
  name                     = each.key
  for_each                 = var.helix_core_servers
  instance_subnet_id       = each.value.instance_subnet_id
  instance_type            = each.value.instance_type
  storage_type             = each.value.storage.type
  depot_volume_size        = each.value.storage.depot_volume_size
  metadata_volume_size     = each.value.storage.metadata_volume_size
  logs_volume_size         = each.value.storage.logs_volume_size
  internal                 = each.value.internal
  existing_security_groups = each.value.existing_security_groups != null ? each.value.existing_security_groups : [aws_security_group.helix_core.id]
  server_type              = each.value.server_type
  project_prefix           = var.project_prefix
  tags                     = local.tags
}

module "helix_swarm" {
  count                                = var.helix_swarm != null ? 1 : 0
  source                               = "./helix-swarm"
  instance_subnet_id                   = var.helix_swarm.instance_subnet_id
  swarm_alb_subnets                    = var.helix_swarm.alb_subnet_ids
  enable_swarm_alb_access_logs         = var.helix_swarm.enable_swarm_alb_access_logs
  swarm_alb_access_logs_bucket         = var.helix_swarm.swarm_alb_access_logs_bucket
  swarm_alb_access_logs_prefix         = var.helix_swarm.swarm_alb_access_logs_prefix
  enable_swarm_alb_deletion_protection = var.helix_swarm.enable_swarm_alb_deletion_protection
  certificate_arn                      = var.helix_swarm.certificate_arn
  existing_security_groups             = var.helix_swarm.existing_security_groups
  internal                             = var.helix_swarm.internal
  custom_swarm_role                    = var.helix_swarm.custom_swarm_role
  create_swarm_default_role            = var.helix_swarm.create_swarm_default_role
  vpc_id                               = var.vpc_id
  project_prefix                       = var.project_prefix
  environment                          = var.environment
  tags                                 = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "helix_core_inbound_swarm" {
  count                        = var.helix_swarm != null ? 1 : 0
  security_group_id            = aws_security_group.helix_core.id
  from_port                    = 1666
  ip_protocol                  = "tcp"
  to_port                      = 1666
  referenced_security_group_id = module.helix_swarm[0].security_group_id
  description                  = "Helix Core in from Helix Swarm"
}







