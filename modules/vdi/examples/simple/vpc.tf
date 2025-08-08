# VPC Configuration for VDI Example

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "vdi_vpc" {
  cidr_block = var.vpc_cidr
  
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "vdi_igw" {
  vpc_id = aws_vpc.vdi_vpc.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Public subnets
resource "aws_subnet" "vdi_public_subnet" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.vdi_vpc.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
  })
}


# Route table for public subnets
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

# Associate public subnets with public route table
resource "aws_route_table_association" "vdi_public_rta" {
  count          = length(aws_subnet.vdi_public_subnet)
  subnet_id      = aws_subnet.vdi_public_subnet[count.index].id
  route_table_id = aws_route_table.vdi_public_rt.id
}

# Private subnets for Simple AD
resource "aws_subnet" "vdi_private_subnet" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.vdi_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
  })
}

# Route table for private subnets (no internet gateway)
resource "aws_route_table" "vdi_private_rt" {
  vpc_id = aws_vpc.vdi_vpc.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt"
  })
}

# Associate private subnets with private route table
resource "aws_route_table_association" "vdi_private_rta" {
  count          = length(aws_subnet.vdi_private_subnet)
  subnet_id      = aws_subnet.vdi_private_subnet[count.index].id
  route_table_id = aws_route_table.vdi_private_rt.id
}