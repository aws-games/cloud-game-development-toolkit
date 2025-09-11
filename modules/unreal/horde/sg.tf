###########################################
# Unreal Horde External ALB Security Group
###########################################

resource "aws_security_group" "unreal_horde_external_alb_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to Horde service ALB
  count       = var.create_external_alb ? 1 : 0
  name        = "${local.name_prefix}-ext-ALB"
  vpc_id      = var.vpc_id
  description = "External Unreal Horde ALB Security Group."
  tags        = local.tags
}

# Outbound access from External ALB to Containers
resource "aws_vpc_security_group_egress_rule" "unreal_horde_external_alb_outbound_service_api" {
  count                        = var.create_external_alb ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_external_alb_sg[0].id
  description                  = "Allow outbound traffic from External Unreal Horde ALB to Unreal Horde service API."
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = var.container_api_port
  to_port                      = var.container_api_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "unreal_horde_external_alb_outbound_service_grpc" {
  count                        = var.create_external_alb ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_external_alb_sg[0].id
  description                  = "Allow outbound traffic from External Unreal Horde ALB to Unreal Horde service GRPC channel."
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = var.container_grpc_port
  to_port                      = var.container_grpc_port
  ip_protocol                  = "tcp"
}

###########################################
# Unreal Horde Internal ALB Security Group
###########################################

resource "aws_security_group" "unreal_horde_internal_alb_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to Horde service ALB
  count       = var.create_internal_alb ? 1 : 0
  name        = "${local.name_prefix}-int-ALB"
  vpc_id      = var.vpc_id
  description = "Internal Unreal Horde ALB Security Group."
  tags        = local.tags
}

# Outbound access from Internal ALB to Containers
resource "aws_vpc_security_group_egress_rule" "unreal_horde_internal_alb_outbound_service_api" {
  count                        = var.create_internal_alb ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_internal_alb_sg[0].id
  description                  = "Allow outbound traffic from internal Unreal Horde ALB to Unreal Horde service API."
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = var.container_api_port
  to_port                      = var.container_api_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "unreal_horde_internal_alb_outbound_service_grpc" {
  count                        = var.create_internal_alb ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_internal_alb_sg[0].id
  description                  = "Allow outbound traffic from internal Unreal Horde ALB to Unreal Horde service GRPC channel."
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = var.container_grpc_port
  to_port                      = var.container_grpc_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "unreal_horde_internal_alb_outbound_service_dex" {
  count                        = var.create_internal_alb && var.deploy_dex ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_internal_alb_sg[0].id
  description                  = "Allow outbound traffic from internal Unreal Horde ALB to Unreal Horde service dex channel."
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = var.dex_container_port
  to_port                      = var.dex_container_port
  ip_protocol                  = "tcp"
}

########################################
# Unreal Horde Service Security Group
########################################

# Unreal Horde Service Security Group (attached to containers)
resource "aws_security_group" "unreal_horde_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to Horde service
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "Unreal Horde Service Security Group"
  tags        = local.tags
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "unreal_horde_outbound_ipv4" {
  security_group_id = aws_security_group.unreal_horde_sg.id
  description       = "Allow outbound traffic from Unreal Horde service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "unreal_horde_outbound_ipv6" {
  security_group_id = aws_security_group.unreal_horde_sg.id
  description       = "Allow outbound traffic from unreal_horde service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Inbound access to Containers from External ALB on API port
resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_external_alb_api" {
  count                        = var.create_external_alb ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound web server traffic from Unreal Horde external ALB."
  referenced_security_group_id = aws_security_group.unreal_horde_external_alb_sg[0].id
  from_port                    = var.container_api_port
  to_port                      = var.container_api_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_external_alb_grpc" {
  count                        = var.create_external_alb ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound GRPC traffic from Unreal Horde external ALB."
  referenced_security_group_id = aws_security_group.unreal_horde_external_alb_sg[0].id
  from_port                    = var.container_grpc_port
  to_port                      = var.container_grpc_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_external_alb_dex" {
  count                        = var.create_external_alb && var.deploy_dex ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound dex traffic from Unreal Horde external ALB."
  referenced_security_group_id = aws_security_group.unreal_horde_external_alb_sg[0].id
  from_port                    = var.dex_container_port
  to_port                      = var.dex_container_port
  ip_protocol                  = "tcp"
}

# Inbound access to Containers from Internal ALB on API port
resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_internal_alb_api" {
  count                        = var.create_internal_alb ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound web service traffic from Unreal Horde internal ALB."
  referenced_security_group_id = aws_security_group.unreal_horde_internal_alb_sg[0].id
  from_port                    = var.container_api_port
  to_port                      = var.container_api_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_internal_alb_grpc" {
  count                        = var.create_internal_alb ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound GRPC traffic from Unreal Horde internal ALB."
  referenced_security_group_id = aws_security_group.unreal_horde_internal_alb_sg[0].id
  from_port                    = var.container_grpc_port
  to_port                      = var.container_grpc_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "unreal_horde_inbound_internal_alb_dex" {
  count                        = var.create_internal_alb && var.deploy_dex ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_sg.id
  description                  = "Allow inbound dex traffic from Unreal Horde internal ALB."
  referenced_security_group_id = aws_security_group.unreal_horde_internal_alb_sg[0].id
  from_port                    = var.dex_container_port
  to_port                      = var.dex_container_port
  ip_protocol                  = "tcp"
}

# unreal_horde Elasticache Redis Security Group
resource "aws_security_group" "unreal_horde_elasticache_sg" {
  count = var.custom_cache_connection_config == null ? 1 : 0
  #checkov:skip=CKV2_AWS_5:Security group is attached to Elasticache cluster
  name        = "${local.name_prefix}-elasticache"
  vpc_id      = var.vpc_id
  description = "unreal_horde Elasticache Redis Security Group"
  tags        = local.tags
}
resource "aws_vpc_security_group_ingress_rule" "unreal_horde_elasticache_ingress" {
  count = var.custom_cache_connection_config == null ? 1 : 0

  security_group_id            = aws_security_group.unreal_horde_elasticache_sg[0].id
  description                  = "Allow inbound traffic from unreal_horde service to Redis"
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = var.elasticache_port
  to_port                      = var.elasticache_port
  ip_protocol                  = "tcp"
}

# unreal_horde DocumentDB Cluster Security Group
resource "aws_security_group" "unreal_horde_docdb_sg" {
  count = var.database_connection_string == null ? 1 : 0

  name        = "${local.name_prefix}-docdb"
  vpc_id      = var.vpc_id
  description = "unreal_horde DocumentDB Cluster Security Group"
  tags        = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "unreal_horde_docdb_ingress" {
  count = var.database_connection_string == null ? 1 : 0

  security_group_id            = aws_security_group.unreal_horde_docdb_sg[0].id
  description                  = "Allow inbound traffic from unreal_horde service to DocumentDB"
  referenced_security_group_id = aws_security_group.unreal_horde_sg.id
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
}

###########################################
# Unreal Horde Agents Security Group
###########################################

resource "aws_security_group" "unreal_horde_agent_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to Horde agent autoscaling groups

  count       = length(var.agents) > 0 ? 1 : 0
  name        = "${local.name_prefix}-agents"
  vpc_id      = var.vpc_id
  description = "Unreal Horde agents Security Group"
  tags        = local.tags
}

# Outbound access from Agents to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "unreal_horde_agents_outbound_ipv4" {
  count             = length(var.agents) > 0 ? 1 : 0
  security_group_id = aws_security_group.unreal_horde_agent_sg[0].id
  description       = "Allow outbound traffic from Unreal Horde agents to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Agents to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "unreal_horde_agents_outbound_ipv6" {
  count             = length(var.agents) > 0 ? 1 : 0
  security_group_id = aws_security_group.unreal_horde_agent_sg[0].id
  description       = "Allow outbound traffic from Unreal Horde agents to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Horde Internal ALB allow inbound HTTPS access from Agents
resource "aws_vpc_security_group_ingress_rule" "unreal_horde_service_inbound_agents" {
  count                        = var.create_internal_alb && length(var.agents) > 0 ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_internal_alb_sg[0].id
  description                  = "Allow inbound traffic to Unreal Horde Service from agents."
  referenced_security_group_id = aws_security_group.unreal_horde_agent_sg[0].id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# Horde agents allow inbound access from other agents
resource "aws_vpc_security_group_ingress_rule" "unreal_horde_agents_inbound_agents" {
  count                        = length(var.agents) > 0 ? 1 : 0
  security_group_id            = aws_security_group.unreal_horde_agent_sg[0].id
  description                  = "Allow inbound traffic to Horde Agents from other Horde Agents."
  referenced_security_group_id = aws_security_group.unreal_horde_agent_sg[0].id
  from_port                    = 7000
  to_port                      = 7010
  ip_protocol                  = "tcp"
}
