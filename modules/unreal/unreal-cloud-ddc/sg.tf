################################################################################
# Dynamic VPC CIDR Detection
################################################################################

# Use dynamic VPC CIDR instead of hardcoded ranges
data "aws_vpc" "main" {
  id = var.existing_vpc_id
}

# Dynamic IP detection (optional)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

################################################################################
# NLB Security Group (Standardized)
################################################################################

resource "aws_security_group" "nlb" {
  count  = var.ddc_infra_config != null ? 1 : 0
  name   = "${local.name_prefix}-nlb-${local.name_suffix}"
  vpc_id = var.existing_vpc_id
  
  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-nlb-${local.name_suffix}"
    Type   = "Network Load Balancer"
    Access = var.internet_facing ? "Internet-facing" : "Internal"
    Region = var.region
  })

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP access from allowed CIDRs
resource "aws_vpc_security_group_ingress_rule" "nlb_http_cidrs" {
  count             = var.ddc_infra_config != null ? length(var.allowed_external_cidrs) : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "HTTP access from allowed CIDR ${var.allowed_external_cidrs[count.index]}"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.allowed_external_cidrs[count.index]
  
  tags = {
    Name = "nlb-http-${count.index}"
  }
}

# HTTPS access from allowed CIDRs
resource "aws_vpc_security_group_ingress_rule" "nlb_https_cidrs" {
  count             = var.ddc_infra_config != null ? length(var.allowed_external_cidrs) : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "HTTPS access from allowed CIDR ${var.allowed_external_cidrs[count.index]}"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.allowed_external_cidrs[count.index]
  
  tags = {
    Name = "nlb-https-${count.index}"
  }
}

# HTTP access from prefix list
resource "aws_vpc_security_group_ingress_rule" "nlb_http_prefix" {
  count             = var.ddc_infra_config != null && var.external_prefix_list_id != null ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "HTTP access from managed prefix list"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = var.external_prefix_list_id
  
  tags = {
    Name = "nlb-http-prefix"
  }
}

# HTTPS access from prefix list
resource "aws_vpc_security_group_ingress_rule" "nlb_https_prefix" {
  count             = var.ddc_infra_config != null && var.external_prefix_list_id != null ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "HTTPS access from managed prefix list"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = var.external_prefix_list_id
  
  tags = {
    Name = "nlb-https-prefix"
  }
}

# VPC CIDR access for internal load balancers
resource "aws_vpc_security_group_ingress_rule" "nlb_http_vpc" {
  count             = var.ddc_infra_config != null && !var.internet_facing ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "HTTP access from VPC CIDR (internal load balancer)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = data.aws_vpc.main.cidr_block
  
  tags = {
    Name = "nlb-http-vpc"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_https_vpc" {
  count             = var.ddc_infra_config != null && !var.internet_facing ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "HTTPS access from VPC CIDR (internal load balancer)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = data.aws_vpc.main.cidr_block
  
  tags = {
    Name = "nlb-https-vpc"
  }
}

# NLB egress (acceptable 0.0.0.0/0 for AWS APIs)
resource "aws_vpc_security_group_egress_rule" "nlb_egress" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "All outbound traffic (AWS APIs, updates, container registry)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  
  tags = {
    Name = "nlb-egress-all"
  }
}

################################################################################
# Internal Service Communication Security Group
################################################################################

resource "aws_security_group" "internal" {
  count  = var.ddc_infra_config != null ? 1 : 0
  name   = "${local.name_prefix}-internal-${local.name_suffix}"
  vpc_id = var.existing_vpc_id
  
  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-internal-${local.name_suffix}"
    Type        = "Internal Service Communication"
    Description = "Internal communication between DDC services"
    Region      = var.region
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ScyllaDB CQL port (internal communication only)
resource "aws_vpc_security_group_ingress_rule" "internal_scylla_cql" {
  count                        = var.ddc_infra_config != null ? 1 : 0
  security_group_id            = aws_security_group.internal[0].id
  description                  = "ScyllaDB CQL port for internal communication"
  ip_protocol                  = "tcp"
  from_port                    = 9042
  to_port                      = 9042
  referenced_security_group_id = aws_security_group.internal[0].id
  
  tags = {
    Name = "internal-scylla-cql"
  }
}

# Internal service egress (acceptable 0.0.0.0/0 for AWS APIs)
resource "aws_vpc_security_group_egress_rule" "internal_egress" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.internal[0].id
  description       = "All outbound traffic (AWS APIs, updates, container registry)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  
  tags = {
    Name = "internal-egress-all"
  }
}

################################################################################
# User-Controlled Access Rules
################################################################################

# Access from existing security groups (user-controlled)
resource "aws_vpc_security_group_ingress_rule" "nlb_from_users" {
  count                        = var.ddc_infra_config != null ? length(var.existing_security_groups) : 0
  security_group_id            = aws_security_group.nlb[0].id
  description                  = "DDC traffic from user security group ${var.existing_security_groups[count.index]}"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = var.existing_security_groups[count.index]
  
  tags = {
    Name = "nlb-from-users-${count.index}"
  }
}

# NLB to EKS cluster communication
resource "aws_vpc_security_group_egress_rule" "nlb_to_cluster" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "To EKS cluster DDC services"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 8091
  cidr_ipv4         = data.aws_vpc.main.cidr_block
  
  tags = {
    Name = "nlb-to-cluster"
  }
}

# EKS cluster accepts traffic from NLB
resource "aws_vpc_security_group_ingress_rule" "eks_cluster_from_nlb" {
  count                        = var.ddc_infra_config != null ? 1 : 0
  security_group_id            = module.ddc_infra[0].cluster_security_group_id
  description                  = "Allow traffic from DDC NLB to EKS cluster"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = aws_security_group.nlb[0].id
  
  tags = {
    Name = "eks-cluster-from-nlb"
  }
}