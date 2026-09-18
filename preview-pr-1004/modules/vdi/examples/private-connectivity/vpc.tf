##########################################
# VPC
##########################################
resource "aws_vpc" "vdi_vpc" {
  #checkov:skip=CKV2_AWS_11:VPC flow logging not required for VDI examples - adds cost without benefit
  #checkov:skip=CKV2_AWS_12:Default security group restrictions handled by module security groups
  cidr_block           = local.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-vpc"
  })
}

##########################################
# Subnets
##########################################
# Public subnet for NAT Gateway
resource "aws_subnet" "vdi_public_subnet" {
  #checkov:skip=CKV_AWS_130:Public IP assignment required for NAT Gateway subnet
  vpc_id                  = aws_vpc.vdi_vpc.id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-public-subnet"
  })
}

# Private subnet for VDI instances
resource "aws_subnet" "vdi_private_subnet" {
  vpc_id            = aws_vpc.vdi_vpc.id
  cidr_block        = local.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-private-subnet"
  })
}

##########################################
# Internet Gateway
##########################################
resource "aws_internet_gateway" "vdi_igw" {
  vpc_id = aws_vpc.vdi_vpc.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-igw"
  })
}

##########################################
# NAT Gateway
##########################################
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-nat-eip"
  })
}

resource "aws_nat_gateway" "vdi_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.vdi_public_subnet.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-nat"
  })

  depends_on = [aws_internet_gateway.vdi_igw]
}

##########################################
# Route Tables
##########################################
# Public route table
resource "aws_route_table" "vdi_public_rt" {
  vpc_id = aws_vpc.vdi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vdi_igw.id
  }

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-public-rt"
  })
}

# Private route table
resource "aws_route_table" "vdi_private_rt" {
  vpc_id = aws_vpc.vdi_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vdi_nat.id
  }

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-private-rt"
  })
}

# Route table associations
resource "aws_route_table_association" "vdi_public_rta" {
  subnet_id      = aws_subnet.vdi_public_subnet.id
  route_table_id = aws_route_table.vdi_public_rt.id
}

resource "aws_route_table_association" "vdi_private_rta" {
  subnet_id      = aws_subnet.vdi_private_subnet.id
  route_table_id = aws_route_table.vdi_private_rt.id
}
