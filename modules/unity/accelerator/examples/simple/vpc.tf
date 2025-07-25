resource "aws_vpc" "unity_accelerator_vpc" {
  cidr_block = local.vpc_cidr_block
  tags = merge(local.tags,
    {
      Name = "unity-accelerator-vpc"
    }
  )
  enable_dns_hostnames = true
  #checkov:skip=CKV2_AWS_11: VPC flow logging disabled by design
}

# Set default SG to restrict all traffic
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.unity_accelerator_vpc.id
}

resource "aws_subnet" "public_subnets" {
  count             = length(local.public_subnet_cidrs)
  vpc_id            = aws_vpc.unity_accelerator_vpc.id
  cidr_block        = element(local.public_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags,
    {
      Name = "public-subnet-${count.index + 1}"
    }
  )
}

resource "aws_subnet" "private_subnets" {
  count             = length(local.private_subnet_cidrs)
  vpc_id            = aws_vpc.unity_accelerator_vpc.id
  cidr_block        = element(local.private_subnet_cidrs, count.index)
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags,
    {
      Name = "private-subnet-${count.index + 1}"
    }
  )
}

##########################################
# Internet Gateway
##########################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.unity_accelerator_vpc.id
  tags = merge(local.tags,
    {
      Name = "unity-accelerator-igw"
    }
  )
}

##########################################
# Route Tables & NAT Gateway
##########################################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.unity_accelerator_vpc.id

  # public route to the internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.tags,
    {
      Name = "unity-accelerator-public-rt"
    }
  )
}

resource "aws_route_table_association" "public_rt_asso" {
  count          = length(aws_subnet.public_subnets)
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}

resource "aws_eip" "nat_gateway_eip" {
  depends_on = [aws_internet_gateway.igw]
  #checkov:skip=CKV2_AWS_19:EIP associated with NAT Gateway through association ID
  tags = merge(local.tags,
    {
      Name = "unity-accelerator-nat-eip"
    }
  )
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.unity_accelerator_vpc.id

  tags = merge(local.tags,
    {
      Name = "unity-accelerator-private-rt"
    }
  )
}

# route to the internet through NAT gateway
resource "aws_route" "private_rt_nat_gateway" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "private_rt_asso" {
  count          = length(aws_subnet.private_subnets)
  route_table_id = aws_route_table.private_rt.id
  subnet_id      = aws_subnet.private_subnets[count.index].id
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id
  tags = merge(local.tags,
    {
      Name = "unity-accelerator-nat"
    }
  )
}
