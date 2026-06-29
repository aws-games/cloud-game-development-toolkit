resource "aws_vpc" "primary" {
  cidr_block           = local.vpc_cidr_block
  enable_dns_hostnames = true
  tags = merge(local.tags, {
    Name = "horde-multiregion-vpc"
  })
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.primary.id
}

resource "aws_subnet" "public" {
  count             = length(local.public_subnet_cidrs)
  vpc_id            = aws_vpc.primary.id
  cidr_block        = element(local.public_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)
  tags = merge(local.tags, {
    Name = "pub-subnet-${count.index + 1}"
  })
}

resource "aws_subnet" "private" {
  count             = length(local.private_subnet_cidrs)
  vpc_id            = aws_vpc.primary.id
  cidr_block        = element(local.private_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)
  tags = merge(local.tags, {
    Name = "pvt-subnet-${count.index + 1}"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.primary.id
  tags = merge(local.tags, {
    Name = "horde-multiregion-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.primary.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.tags, {
    Name = "horde-multiregion-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.igw]
  tags = merge(local.tags, {
    Name = "horde-multiregion-nat-eip"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = merge(local.tags, {
    Name = "horde-multiregion-nat"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.primary.id
  tags = merge(local.tags, {
    Name = "horde-multiregion-private-rt"
  })
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}
