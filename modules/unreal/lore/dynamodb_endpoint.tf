# =============================================================================
# DynamoDB interface endpoint for regional caches
#
# The write tier keeps its free same-Region gateway endpoint. When regional-cache CIDRs are
# supplied, this additional interface endpoint gives caches in peered VPCs a private-IP path to
# the write Region's mutable-store and lock tables. Private DNS stays off so the write tier keeps
# using its gateway endpoint; caches use the endpoint-specific URL exported below.
# =============================================================================

locals {
  dynamodb_interface_endpoint_enabled = var.dynamodb_endpoint_client_cidrs != null
  dynamodb_interface_endpoint_actions = [
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:DeleteItem",
    "dynamodb:Query",
    "dynamodb:BatchGetItem",
    "dynamodb:DescribeTable",
    "dynamodb:TransactWriteItems",
  ]
  dynamodb_interface_endpoint_index_actions = ["dynamodb:Query"]
  dynamodb_interface_endpoint_account_condition = {
    StringEquals = {
      "aws:PrincipalAccount" = split(":", module.data.locks_table_arn)[4]
    }
  }
  dynamodb_interface_endpoint_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "LoreRegionalCacheTablesOnly"
        Effect    = "Allow"
        Principal = "*"
        Action    = local.dynamodb_interface_endpoint_actions
        Resource = [
          module.data.mutable_store_table_arn,
          module.data.locks_table_arn,
        ]
        Condition = local.dynamodb_interface_endpoint_account_condition
      },
      {
        Sid       = "LoreRegionalCacheLockIndexQueryOnly"
        Effect    = "Allow"
        Principal = "*"
        Action    = local.dynamodb_interface_endpoint_index_actions
        Resource  = ["${module.data.locks_table_arn}/index/*"]
        Condition = local.dynamodb_interface_endpoint_account_condition
      },
    ]
  })
}

resource "aws_security_group" "dynamodb_interface_endpoint" {
  count = local.dynamodb_interface_endpoint_enabled ? 1 : 0

  name_prefix = "${local.name_prefix}-ddb-vpce-"
  vpc_id      = local.vpc_id
  description = "DynamoDB interface endpoint access for regional Lore caches"

  tags = merge(local.tags, { Name = "${local.name_prefix}-ddb-vpce-sg" })

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "dynamodb_interface_endpoint_https" {
  for_each = toset(coalesce(var.dynamodb_endpoint_client_cidrs, []))

  security_group_id = aws_security_group.dynamodb_interface_endpoint[0].id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "DynamoDB HTTPS from regional cache ${each.value}"
}

resource "aws_vpc_endpoint" "dynamodb_interface" {
  count = local.dynamodb_interface_endpoint_enabled ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.dynamodb"
  vpc_endpoint_type   = "Interface"
  ip_address_type     = "ipv4"
  private_dns_enabled = false
  subnet_ids          = coalesce(var.dynamodb_endpoint_subnet_ids, local.private_subnet_ids)
  security_group_ids  = [aws_security_group.dynamodb_interface_endpoint[0].id]
  policy              = local.dynamodb_interface_endpoint_policy

  tags = merge(local.tags, { Name = "${local.name_prefix}-dynamodb-interface-endpoint" })
}

locals {
  dynamodb_interface_endpoint_regional_dns_name = local.dynamodb_interface_endpoint_enabled ? one([
    for entry in aws_vpc_endpoint.dynamodb_interface[0].dns_entry : entry.dns_name
    if startswith(entry.dns_name, "vpce-") && !can(regex("-${data.aws_region.current.region}[a-z]\\.", entry.dns_name))
  ]) : null
}
