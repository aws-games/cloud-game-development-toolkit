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
resource "aws_subnet" "vdi_subnet" {
  #checkov:skip=CKV_AWS_130:Public IP assignment required for VDI public connectivity pattern
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
