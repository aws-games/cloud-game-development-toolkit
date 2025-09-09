##########################################
# VPC
##########################################
resource "aws_vpc" "vdi_vpc" {
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
resource "aws_subnet" "vdi_subnet" {
  vpc_id                  = aws_vpc.vdi_vpc.id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-public-subnet"
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
# Route Tables
##########################################
resource "aws_route_table" "vdi_rt" {
  vpc_id = aws_vpc.vdi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vdi_igw.id
  }

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-vdi-rt"
  })
}

resource "aws_route_table_association" "vdi_rta" {
  subnet_id      = aws_subnet.vdi_subnet.id
  route_table_id = aws_route_table.vdi_rt.id
}