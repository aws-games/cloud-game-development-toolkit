##########################################
# Primary Region VPC (us-east-1)
##########################################
resource "aws_vpc" "perforce_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.project_prefix}-perforce-vpc"
  }
}

resource "aws_internet_gateway" "perforce_igw" {
  vpc_id = aws_vpc.perforce_vpc.id

  tags = {
    Name = "${local.project_prefix}-perforce-igw"
  }
}

# Public subnets
resource "aws_subnet" "public_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.perforce_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.project_prefix}-public-subnet-${count.index + 1}"
  }
}

# Private subnets
resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.perforce_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${local.project_prefix}-private-subnet-${count.index + 1}"
  }
}

# Route tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.perforce_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.perforce_igw.id
  }

  tags = {
    Name = "${local.project_prefix}-public-rt"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.perforce_vpc.id

  tags = {
    Name = "${local.project_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "public_rta" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

##########################################
# Data Sources
##########################################
data "aws_availability_zones" "available" {
  state = "available"
}