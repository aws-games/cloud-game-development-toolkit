##########################################
# Primary Region VPC Infrastructure
##########################################
resource "aws_vpc" "primary" {
  provider = aws.primary
  
  cidr_block           = local.vpc_cidr_primary
  enable_dns_hostnames = true
  enable_dns_support   = true
  #checkov:skip=CKV2_AWS_11: VPC flow logging disabled by design

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-vpc"
  })
}

resource "aws_default_security_group" "primary_default" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-vpc-default-sg"
  })
}

# Primary Region Subnets
resource "aws_subnet" "primary_public" {
  provider = aws.primary
  count    = 2

  vpc_id                  = aws_vpc.primary.id
  cidr_block              = local.primary_public_subnet_cidrs[count.index]
  availability_zone       = local.azs_region_1[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-public-${count.index + 1}"
  })
}

resource "aws_subnet" "primary_private" {
  provider = aws.primary
  count    = 2

  vpc_id            = aws_vpc.primary.id
  cidr_block        = local.primary_private_subnet_cidrs[count.index]
  availability_zone = local.azs_region_1[count.index]

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-private-${count.index + 1}"
  })
}

# Primary Region Internet Gateway
resource "aws_internet_gateway" "primary_igw" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-igw"
  })
}

# Primary Region NAT Gateway
resource "aws_eip" "primary_nat_eip" {
  provider   = aws.primary
  depends_on = [aws_internet_gateway.primary_igw]
  #checkov:skip=CKV2_AWS_19:EIP associated with NAT Gateway through association ID

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-nat-eip"
  })
}

resource "aws_nat_gateway" "primary_nat" {
  provider      = aws.primary
  allocation_id = aws_eip.primary_nat_eip.id
  subnet_id     = aws_subnet.primary_public[0].id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-nat"
  })
}

# Primary Region Route Tables
resource "aws_route_table" "primary_public_rt" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary_igw.id
  }

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-public-rt"
  })
}

resource "aws_route_table" "primary_private_rt" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-private-rt"
  })
}

resource "aws_route" "primary_private_nat" {
  provider               = aws.primary
  route_table_id         = aws_route_table.primary_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.primary_nat.id
}

resource "aws_route_table_association" "primary_public_rt_asso" {
  provider       = aws.primary
  count          = length(aws_subnet.primary_public)
  route_table_id = aws_route_table.primary_public_rt.id
  subnet_id      = aws_subnet.primary_public[count.index].id
}

resource "aws_route_table_association" "primary_private_rt_asso" {
  provider       = aws.primary
  count          = length(aws_subnet.primary_private)
  route_table_id = aws_route_table.primary_private_rt.id
  subnet_id      = aws_subnet.primary_private[count.index].id
}

##########################################
# Secondary Region VPC Infrastructure
##########################################
resource "aws_vpc" "secondary" {
  provider = aws.secondary
  
  cidr_block           = local.vpc_cidr_secondary
  enable_dns_hostnames = true
  enable_dns_support   = true
  #checkov:skip=CKV2_AWS_11: VPC flow logging disabled by design

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-vpc"
  })
}

resource "aws_default_security_group" "secondary_default" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-vpc-default-sg"
  })
}

# Secondary Region Subnets
resource "aws_subnet" "secondary_public" {
  provider = aws.secondary
  count    = 2

  vpc_id                  = aws_vpc.secondary.id
  cidr_block              = local.secondary_public_subnet_cidrs[count.index]
  availability_zone       = local.azs_region_2[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-public-${count.index + 1}"
  })
}

resource "aws_subnet" "secondary_private" {
  provider = aws.secondary
  count    = 2

  vpc_id            = aws_vpc.secondary.id
  cidr_block        = local.secondary_private_subnet_cidrs[count.index]
  availability_zone = local.azs_region_2[count.index]

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-private-${count.index + 1}"
  })
}

# Secondary Region Internet Gateway
resource "aws_internet_gateway" "secondary_igw" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-igw"
  })
}

# Secondary Region NAT Gateway
resource "aws_eip" "secondary_nat_eip" {
  provider   = aws.secondary
  depends_on = [aws_internet_gateway.secondary_igw]
  #checkov:skip=CKV2_AWS_19:EIP associated with NAT Gateway through association ID

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-nat-eip"
  })
}

resource "aws_nat_gateway" "secondary_nat" {
  provider      = aws.secondary
  allocation_id = aws_eip.secondary_nat_eip.id
  subnet_id     = aws_subnet.secondary_public[0].id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-nat"
  })
}

# Secondary Region Route Tables
resource "aws_route_table" "secondary_public_rt" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary_igw.id
  }

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-public-rt"
  })
}

resource "aws_route_table" "secondary_private_rt" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-private-rt"
  })
}

resource "aws_route" "secondary_private_nat" {
  provider               = aws.secondary
  route_table_id         = aws_route_table.secondary_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.secondary_nat.id
}

resource "aws_route_table_association" "secondary_public_rt_asso" {
  provider       = aws.secondary
  count          = length(aws_subnet.secondary_public)
  route_table_id = aws_route_table.secondary_public_rt.id
  subnet_id      = aws_subnet.secondary_public[count.index].id
}

resource "aws_route_table_association" "secondary_private_rt_asso" {
  provider       = aws.secondary
  count          = length(aws_subnet.secondary_private)
  route_table_id = aws_route_table.secondary_private_rt.id
  subnet_id      = aws_subnet.secondary_private[count.index].id
}

##########################################
# VPC Peering Connection
##########################################
resource "aws_vpc_peering_connection" "primary_to_secondary" {
  provider    = aws.primary
  vpc_id      = aws_vpc.primary.id
  peer_vpc_id = aws_vpc.secondary.id
  peer_region = local.regions.secondary.name
  auto_accept = false

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-primary-to-secondary-peering"
  })
}

resource "aws_vpc_peering_connection_accepter" "secondary_accept" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept               = true

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-secondary-accept-peering"
  })
}

# Cross-region routes for VPC peering
resource "aws_route" "primary_to_secondary_peering" {
  provider                  = aws.primary
  route_table_id            = aws_route_table.primary_private_rt.id
  destination_cidr_block    = aws_vpc.secondary.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}

resource "aws_route" "secondary_to_primary_peering" {
  provider                  = aws.secondary
  route_table_id            = aws_route_table.secondary_private_rt.id
  destination_cidr_block    = aws_vpc.primary.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}