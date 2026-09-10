##################################################
# VPC
##################################################

resource "aws_vpc" "horde_pipeline_vpc" {
  cidr_block           = local.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpc"
  })

  #checkov:skip=CKV2_AWS_11: VPC flow logging disabled by design for cost optimization in this sample
}

# Lock down the default security group so it permits no traffic.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.horde_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-default-sg"
  })
}

##################################################
# Subnets - Public (ALBs / NAT)
##################################################

resource "aws_subnet" "public_subnets" {
  count             = length(local.public_subnet_cidrs)
  vpc_id            = aws_vpc.horde_pipeline_vpc.id
  cidr_block        = element(local.public_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Tier = "public"
  })
}

##################################################
# Subnets - Private Application (Horde ECS, Perforce, agents)
##################################################

resource "aws_subnet" "private_app_subnets" {
  count             = length(local.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.horde_pipeline_vpc.id
  cidr_block        = element(local.private_app_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-app-subnet-${count.index + 1}"
    Tier = "private-application"
  })
}

##################################################
# Subnets - Private Service (FSxN, DocumentDB, ElastiCache)
##################################################

resource "aws_subnet" "private_svc_subnets" {
  count             = length(local.private_svc_subnet_cidrs)
  vpc_id            = aws_vpc.horde_pipeline_vpc.id
  cidr_block        = element(local.private_svc_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-svc-subnet-${count.index + 1}"
    Tier = "private-service"
  })
}

##################################################
# Internet Gateway
##################################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.horde_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

##################################################
# NAT Gateway (single, for sample cost optimization)
##################################################

resource "aws_eip" "nat_gateway_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nat-eip"
  })

  #checkov:skip=CKV2_AWS_19: EIP associated with NAT Gateway through association ID
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.igw]
}

##################################################
# Route Tables - Public
##################################################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.horde_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rt_asso" {
  count          = length(aws_subnet.public_subnets)
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}

##################################################
# Route Tables - Private Application
##################################################

resource "aws_route_table" "private_app_rt" {
  vpc_id = aws_vpc.horde_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-app-rt"
    Tier = "private-application"
  })
}

resource "aws_route" "private_app_nat_access" {
  route_table_id         = aws_route_table.private_app_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "private_app_rt_asso" {
  count          = length(aws_subnet.private_app_subnets)
  route_table_id = aws_route_table.private_app_rt.id
  subnet_id      = aws_subnet.private_app_subnets[count.index].id
}

##################################################
# Route Tables - Private Service
##################################################

resource "aws_route_table" "private_svc_rt" {
  vpc_id = aws_vpc.horde_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-svc-rt"
    Tier = "private-service"
  })
}

resource "aws_route" "private_svc_nat_access" {
  route_table_id         = aws_route_table.private_svc_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "private_svc_rt_asso" {
  count          = length(aws_subnet.private_svc_subnets)
  route_table_id = aws_route_table.private_svc_rt.id
  subnet_id      = aws_subnet.private_svc_subnets[count.index].id
}

##################################################
# VPC Endpoints
#
# Allow agents in the private tiers to reach S3 and Secrets Manager without
# traversing the public internet.
##################################################

# Security group for interface endpoints. Ingress is restricted to in-VPC
# HTTPS traffic only (least privilege) - never a wildcard.
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.name_prefix}-vpc-endpoints"
  description = "Security group for interface VPC endpoints (HTTPS from within the VPC)."
  vpc_id      = aws_vpc.horde_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpc-endpoints"
  })
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_https_from_vpc" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "Allow HTTPS from within the VPC to interface endpoints."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc_cidr_block
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoints_egress" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "Allow all egress from interface endpoints."
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# S3 - Gateway endpoint (attached to all private route tables).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.horde_pipeline_vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_app_rt.id,
    aws_route_table.private_svc_rt.id,
  ]

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

# Secrets Manager - Interface endpoint (in the private application subnets).
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.horde_pipeline_vpc.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app_subnets[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-secretsmanager-endpoint"
  })
}
