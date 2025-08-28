# Internet Gateways
resource "aws_internet_gateway" "primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-igw"
  })
}

resource "aws_internet_gateway" "secondary" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-igw"
  })
}

# NAT Gateways
resource "aws_eip" "primary_nat" {
  provider = aws.primary
  domain   = "vpc"
  
  depends_on = [aws_internet_gateway.primary]

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-nat-eip"
  })
}

resource "aws_eip" "secondary_nat" {
  provider = aws.secondary
  domain   = "vpc"
  
  depends_on = [aws_internet_gateway.secondary]

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-nat-eip"
  })
}

resource "aws_nat_gateway" "primary" {
  provider      = aws.primary
  allocation_id = aws_eip.primary_nat.id
  subnet_id     = aws_subnet.primary_public[0].id

  depends_on = [aws_internet_gateway.primary]

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-nat"
  })
}

resource "aws_nat_gateway" "secondary" {
  provider      = aws.secondary
  allocation_id = aws_eip.secondary_nat.id
  subnet_id     = aws_subnet.secondary_public[0].id

  depends_on = [aws_internet_gateway.secondary]

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-nat"
  })
}

# Route Tables
resource "aws_route_table" "primary_public" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-public-rt"
  })
}

resource "aws_route_table" "primary_private" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.primary.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-private-rt"
  })
}

resource "aws_route_table" "secondary_public" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-public-rt"
  })
}

resource "aws_route_table" "secondary_private" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.secondary.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-private-rt"
  })
}

# Route Table Associations
resource "aws_route_table_association" "primary_public" {
  provider = aws.primary
  count    = length(aws_subnet.primary_public)

  subnet_id      = aws_subnet.primary_public[count.index].id
  route_table_id = aws_route_table.primary_public.id
}

resource "aws_route_table_association" "primary_private" {
  provider = aws.primary
  count    = length(aws_subnet.primary_private)

  subnet_id      = aws_subnet.primary_private[count.index].id
  route_table_id = aws_route_table.primary_private.id
}

resource "aws_route_table_association" "secondary_public" {
  provider = aws.secondary
  count    = length(aws_subnet.secondary_public)

  subnet_id      = aws_subnet.secondary_public[count.index].id
  route_table_id = aws_route_table.secondary_public.id
}

resource "aws_route_table_association" "secondary_private" {
  provider = aws.secondary
  count    = length(aws_subnet.secondary_private)

  subnet_id      = aws_subnet.secondary_private[count.index].id
  route_table_id = aws_route_table.secondary_private.id
}

# VPC Peering between regions
resource "aws_vpc_peering_connection" "primary_to_secondary" {
  provider = aws.primary
  
  vpc_id        = aws_vpc.primary.id
  peer_vpc_id   = aws_vpc.secondary.id
  peer_region   = var.regions[1]
  auto_accept   = false
  
  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-primary-to-secondary-peering"
  })
}

# Accept peering connection in secondary region
resource "aws_vpc_peering_connection_accepter" "secondary" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept               = true
  
  tags = merge(local.common_tags, {
    Name = "${var.project_prefix}-secondary-peering-accepter"
  })
}

# Route table updates for peering - Primary region
resource "aws_route" "primary_to_secondary_private" {
  provider = aws.primary
  
  route_table_id            = aws_route_table.primary_private.id
  destination_cidr_block    = var.vpc_cidr_region_2
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}

resource "aws_route" "primary_to_secondary_public" {
  provider = aws.primary
  
  route_table_id            = aws_route_table.primary_public.id
  destination_cidr_block    = var.vpc_cidr_region_2
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}

# Route table updates for peering - Secondary region
resource "aws_route" "secondary_to_primary_private" {
  provider = aws.secondary
  
  route_table_id            = aws_route_table.secondary_private.id
  destination_cidr_block    = var.vpc_cidr_region_1
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}

resource "aws_route" "secondary_to_primary_public" {
  provider = aws.secondary
  
  route_table_id            = aws_route_table.secondary_public.id
  destination_cidr_block    = var.vpc_cidr_region_1
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
}