##########################################
# VPC
##########################################
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  #checkov:skip=CKV2_AWS_11: VPC flow logging disabled by design

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}"
    }
  )
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-default-sg"
    }
  )
}

##########################################
# Subnets
##########################################
resource "aws_subnet" "public" {
  count             = length(local.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
      
      # EKS Cluster Ownership (REQUIRED for all EKS clusters since 2017)
      # Used by: AWS Load Balancer Controller, EBS CSI driver, all EKS add-ons
      "kubernetes.io/cluster/${local.name_prefix}" = "owned"
      
      # EKS Auto Mode Load Balancer Discovery (REQUIRED for EKS Auto Mode only)
      # Used by: EKS Auto Mode to identify eligible subnets for internet-facing load balancers
      # Note: Tags define the "allowed list" - EKS Auto Mode can use ANY tagged subnet (service annotations can filter within this list)
      "kubernetes.io/role/elb" = "1"
    }
  )
}

resource "aws_subnet" "private" {
  count             = length(local.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
      
      # EKS Cluster Ownership (REQUIRED for all EKS clusters since 2017)
      # Used by: AWS Load Balancer Controller, EBS CSI driver, all EKS add-ons
      "kubernetes.io/cluster/${local.name_prefix}" = "owned"
      
      # EKS Auto Mode Load Balancer Discovery (REQUIRED for EKS Auto Mode only)
      # Used by: EKS Auto Mode to identify eligible subnets for internal load balancers
      # Note: Tags define the "allowed list" - EKS Auto Mode can use ANY tagged subnet (service annotations can filter within this list)
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

##########################################
# Internet Gateway
##########################################
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-gateway"
    }
  )
}

##########################################
# Route Tables & NAT Gateway
##########################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-public"
    }
  )
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.main]
  #checkov:skip=CKV2_AWS_19:EIP associated with NAT Gateway through association ID
  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-nat"
    }
  )
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-private"
    }
  )
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-nat-gateway"
    }
  )
}