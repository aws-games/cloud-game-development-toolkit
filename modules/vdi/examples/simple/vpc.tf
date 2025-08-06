resource "aws_vpc" "vdi_vpc" {
  cidr_block = local.vpc_cidr_block
  
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-vpc"
  })
}

# Secure the default security group by restricting all inbound traffic
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vdi_vpc.id

  # No ingress rules defined = no inbound traffic allowed
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-${var.name}-default-sg"
  })
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = local.enable_flow_logs ? 1 : 0
  
  name              = "/aws/vpc/flowlogs/${var.project_prefix}-${var.name}-vpc"
  retention_in_days = local.flow_logs_retention_days
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-vpc-flow-logs"
  })
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs_role" {
  count = local.enable_flow_logs ? 1 : 0
  
  name = "${var.project_prefix}-${var.name}-vpc-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  
  tags = local.tags
}

# IAM policy for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  count = local.enable_flow_logs ? 1 : 0
  
  name = "${var.project_prefix}-${var.name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

# Enable VPC Flow Logs
resource "aws_flow_log" "vpc_flow_logs" {
  count = local.enable_flow_logs ? 1 : 0
  
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = local.flow_logs_traffic_type
  vpc_id               = aws_vpc.vdi_vpc.id
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role[0].arn
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-vpc-flow-logs"
  })
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "vdi_igw" {
  vpc_id = aws_vpc.vdi_vpc.id
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-igw"
  })
}

# Public subnets
resource "aws_subnet" "vdi_public_subnet" {
  count             = length(local.public_subnet_cidrs)
  vpc_id            = aws_vpc.vdi_vpc.id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index % length(local.availability_zones)]
  
  map_public_ip_on_launch = true
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-public-subnet-${count.index + 1}"
  })
}

# Private subnets
resource "aws_subnet" "vdi_private_subnet" {
  count             = length(local.private_subnet_cidrs)
  vpc_id            = aws_vpc.vdi_vpc.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index % length(local.availability_zones)]
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-private-subnet-${count.index + 1}"
  })
}

# Route table for public subnets
resource "aws_route_table" "vdi_public_rt" {
  vpc_id = aws_vpc.vdi_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vdi_igw.id
  }
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-public-rt"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "vdi_public_rta" {
  count          = length(local.public_subnet_cidrs)
  subnet_id      = aws_subnet.vdi_public_subnet[count.index].id
  route_table_id = aws_route_table.vdi_public_rt.id
}

# NAT Gateway for private subnets (if enabled)
resource "aws_eip" "vdi_nat_eip" {
  count      = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.public_subnet_cidrs)) : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.vdi_igw]
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "vdi_nat_gateway" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.public_subnet_cidrs)) : 0
  allocation_id = aws_eip.vdi_nat_eip[count.index].id
  subnet_id     = aws_subnet.vdi_public_subnet[count.index].id
  depends_on    = [aws_internet_gateway.vdi_igw]
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-nat-gateway-${count.index + 1}"
  })
}

# Route table for private subnets
resource "aws_route_table" "vdi_private_rt" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.private_subnet_cidrs)) : 1
  vpc_id = aws_vpc.vdi_vpc.id
  
  tags = merge(local.tags, {
    Name = "${var.project_prefix}-${var.name}-private-rt${var.single_nat_gateway ? "" : "-${count.index + 1}"}"
  })
}

# Route through NAT Gateway if enabled
resource "aws_route" "private_nat_gateway" {
  count                  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.private_subnet_cidrs)) : 0
  route_table_id         = var.single_nat_gateway ? aws_route_table.vdi_private_rt[0].id : aws_route_table.vdi_private_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.vdi_nat_gateway[0].id : aws_nat_gateway.vdi_nat_gateway[count.index].id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "vdi_private_rta" {
  count          = length(local.private_subnet_cidrs)
  subnet_id      = aws_subnet.vdi_private_subnet[count.index].id
  route_table_id = var.enable_nat_gateway ? (
    var.single_nat_gateway ? aws_route_table.vdi_private_rt[0].id : aws_route_table.vdi_private_rt[count.index].id
  ) : aws_route_table.vdi_private_rt[0].id
}
