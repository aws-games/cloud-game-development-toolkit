##########################################
# VPC
##########################################

resource "aws_vpc" "unreal_cloud_ddc_vpc" {
  #checkov:skip=CKV2_AWS_11:flow logs are out of scope for sample architecture.
  region               = var.region
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(var.additional_tags,
    {
      Name = "unreal-cloud-ddc-vpc"
    }
  )
}

resource "aws_default_security_group" "default" {
  region = var.region
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
}

##########################################
# Subnets
##########################################

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnets_cidrs)
  region            = var.region
  vpc_id            = aws_vpc.unreal_cloud_ddc_vpc.id
  cidr_block        = element(var.public_subnets_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = merge(var.additional_tags,
    {
      "kubernetes.io/role/elb" = 1
      Name                     = "unreal-cloud-ddc-public-subnet-${count.index + 1}"
    }
  )

}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnets_cidrs)
  vpc_id            = aws_vpc.unreal_cloud_ddc_vpc.id
  region            = var.region
  cidr_block        = element(var.private_subnets_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = merge(var.additional_tags,
    {
      "kubernetes.io/role/internal-elb" = 1
      Name                              = "unreal-cloud-ddc-private-subnet-${count.index + 1}"
    }
  )

}

##########################################
# Internet Gateway
##########################################

resource "aws_internet_gateway" "igw" {
  region = var.region
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  tags = merge(var.additional_tags,
    {
      Name = "unreal-cloud-ddc-igw"
    }
  )
}

##########################################
# Route Tables & NAT Gateway
##########################################


resource "aws_route_table" "public_rt" {
  region = var.region
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id

  tags = merge(var.additional_tags,
    {
      Name = "unreal-cloud-ddc-public-rt"
    }
  )
}

resource "aws_route" "public_internet_gateway" {
  region                 = var.region
  route_table_id         = aws_route_table.public_rt.id
  gateway_id             = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"

}

resource "aws_route_table_association" "public_rt_asso" {
  count          = length(aws_subnet.public_subnets)
  region         = var.region
  route_table_id = aws_route_table.public_rt.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}

resource "aws_eip" "nat_gateway_eip" {
  depends_on = [aws_internet_gateway.igw]
  region     = var.region
  #checkov:skip=CKV2_AWS_19:EIP associated with NAT Gateway through association ID
  tags = merge(var.additional_tags,
    {
      Name = "unreal-cloud-ddc-nat-eip"
    }
  )
}

resource "aws_route_table" "private_rt" {
  region = var.region
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id

  tags = merge(var.additional_tags,
    {
      Name = "unreal-cloud-ddc-private-rt"
    }
  )
}

resource "aws_route" "private_nat_gateway" {
  region                 = var.region
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "private_rt_asso" {
  count          = length(aws_subnet.private_subnets)
  region         = var.region
  route_table_id = aws_route_table.private_rt.id
  subnet_id      = aws_subnet.private_subnets[count.index].id
}

resource "aws_nat_gateway" "nat_gateway" {
  region        = var.region
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id
  tags = merge(var.additional_tags,
    {
      Name = "unreal-cloud-ddc-nat"
    }
  )
}

resource "aws_vpc_endpoint" "s3" {
  region       = var.region
  vpc_id       = aws_vpc.unreal_cloud_ddc_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
}
