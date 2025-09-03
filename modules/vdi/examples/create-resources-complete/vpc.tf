# VPC Configuration for VDI Example

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "vdi_vpc" {
  # checkov:skip=CKV2_AWS_11:VPC flow logging not required for VDI example deployment
  # checkov:skip=CKV2_AWS_12:Default security group restrictions not applicable to VDI module design
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# Create Internet Gateway
resource "aws_internet_gateway" "vdi_igw" {
  vpc_id = aws_vpc.vdi_vpc.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Create public subnets
resource "aws_subnet" "vdi_public_subnet" {
  # checkov:skip=CKV_AWS_130:VDI instances require public IP assignment for remote access connectivity
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.vdi_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Type = "Public"
  })
}

# Create private subnets (for Managed AD)
resource "aws_subnet" "vdi_private_subnet" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.vdi_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
    Type = "Private"
  })
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "vdi_nat_eip" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip"
  })

  depends_on = [aws_internet_gateway.vdi_igw]
}

# Create NAT Gateway
resource "aws_nat_gateway" "vdi_nat_gateway" {
  allocation_id = aws_eip.vdi_nat_eip.id
  subnet_id     = aws_subnet.vdi_public_subnet[0].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-gateway"
  })

  depends_on = [aws_internet_gateway.vdi_igw]
}

# Create route table for public subnets
resource "aws_route_table" "vdi_public_rt" {
  vpc_id = aws_vpc.vdi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vdi_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

# Create route table for private subnets
resource "aws_route_table" "vdi_private_rt" {
  vpc_id = aws_vpc.vdi_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vdi_nat_gateway.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "vdi_public_rta" {
  count = length(aws_subnet.vdi_public_subnet)

  subnet_id      = aws_subnet.vdi_public_subnet[count.index].id
  route_table_id = aws_route_table.vdi_public_rt.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "vdi_private_rta" {
  count = length(aws_subnet.vdi_private_subnet)

  subnet_id      = aws_subnet.vdi_private_subnet[count.index].id
  route_table_id = aws_route_table.vdi_private_rt.id
}
