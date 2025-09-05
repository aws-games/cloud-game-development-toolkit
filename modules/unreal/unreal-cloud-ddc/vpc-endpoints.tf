################################################################################
# VPC Endpoints for Private AWS API Access
################################################################################

# EKS VPC Endpoint - Auto-enabled for private/hybrid modes
resource "aws_vpc_endpoint" "eks" {
  count = local.eks_uses_vpc_endpoint ? 1 : 0
  
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.ddc_infra_config.eks_node_group_subnets
  security_group_ids  = [aws_security_group.internal[0].id]
  private_dns_enabled = true
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-endpoint"
  })
}

# S3 Gateway VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  count = var.vpc_endpoints != null && var.vpc_endpoints.s3 != null && var.vpc_endpoints.s3.enabled ? 1 : 0
  
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.vpc_endpoints.s3.route_table_ids
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

# CloudWatch Logs VPC Endpoint
resource "aws_vpc_endpoint" "logs" {
  count = var.vpc_endpoints != null && var.vpc_endpoints.logs != null && var.vpc_endpoints.logs.enabled ? 1 : 0
  
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.ddc_infra_config.eks_node_group_subnets
  security_group_ids  = [aws_security_group.internal[0].id]
  private_dns_enabled = true
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-logs-endpoint"
  })
}

# Secrets Manager VPC Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.vpc_endpoints != null && var.vpc_endpoints.secretsmanager != null && var.vpc_endpoints.secretsmanager.enabled ? 1 : 0
  
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.ddc_infra_config.eks_node_group_subnets
  security_group_ids  = [aws_security_group.internal[0].id]
  private_dns_enabled = true
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-secretsmanager-endpoint"
  })
}

# SSM VPC Endpoint
resource "aws_vpc_endpoint" "ssm" {
  count = var.vpc_endpoints != null && var.vpc_endpoints.ssm != null && var.vpc_endpoints.ssm.enabled ? 1 : 0
  
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.ddc_infra_config.eks_node_group_subnets
  security_group_ids  = [aws_security_group.internal[0].id]
  private_dns_enabled = true
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ssm-endpoint"
  })
}