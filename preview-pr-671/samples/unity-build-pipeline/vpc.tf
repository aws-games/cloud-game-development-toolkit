##################################################
# VPC
##################################################

resource "aws_vpc" "unity_pipeline_vpc" {
  cidr_block           = local.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vpc"
  })

  #checkov:skip=CKV2_AWS_11: VPC flow logging disabled by design for cost optimization
}

# Set default security group to restrict all traffic
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.unity_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-default-sg"
  })
}

##################################################
# Subnets
##################################################

resource "aws_subnet" "public_subnets" {
  count             = length(local.public_subnet_cidrs)
  vpc_id            = aws_vpc.unity_pipeline_vpc.id
  cidr_block        = element(local.public_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-public-subnet-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private_subnets" {
  count             = length(local.private_subnet_cidrs)
  vpc_id            = aws_vpc.unity_pipeline_vpc.id
  cidr_block        = element(local.private_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-private-subnet-${count.index + 1}"
    Tier = "private"
  })
}

##################################################
# Internet Gateway
##################################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.unity_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-igw"
  })
}

##################################################
# NAT Gateway
##################################################

resource "aws_eip" "nat_gateway_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-nat-eip"
  })

  #checkov:skip=CKV2_AWS_19: EIP associated with NAT Gateway through association ID
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.igw]
}

##################################################
# Route Tables
##################################################

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.unity_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-public-rt"
    Tier = "public"
  })
}

# Public route to internet
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public_rt_asso" {
  count          = length(aws_subnet.public_subnets)
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.unity_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-private-rt"
    Tier = "private"
  })
}

# Private route to internet through NAT gateway
resource "aws_route" "private_nat_access" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private_rt_asso" {
  count          = length(aws_subnet.private_subnets)
  route_table_id = aws_route_table.private_rt.id
  subnet_id      = aws_subnet.private_subnets[count.index].id
}
