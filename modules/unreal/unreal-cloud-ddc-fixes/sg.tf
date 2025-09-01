################################################################################
# Dynamic VPC CIDR Detection
################################################################################

# Use dynamic VPC CIDR instead of hardcoded ranges
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Dynamic IP detection (optional)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

################################################################################
# External NLB Security Group (Clear and Simple)
################################################################################

resource "aws_security_group" "external_nlb_sg" {
  count  = local.is_external_access && var.ddc_infra_config != null ? 1 : 0
  name   = "${var.project_prefix}-external-nlb-sg"
  vpc_id = var.vpc_id
  
  tags = merge(var.tags, {
    Name   = "${var.project_prefix}-external-nlb-sg"
    Type   = "External NLB"
    Region = var.region
  })

  lifecycle {
    create_before_destroy = true
  }
}

# External HTTP access - one CIDR per rule
resource "aws_vpc_security_group_ingress_rule" "external_nlb_http_cidrs" {
  count             = local.is_external_access && var.ddc_infra_config != null ? length(var.allowed_external_cidrs) : 0
  security_group_id = aws_security_group.external_nlb_sg[0].id
  description       = "HTTP access from allowed CIDR ${var.allowed_external_cidrs[count.index]}"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.allowed_external_cidrs[count.index]
  
  tags = {
    Name = "external-nlb-http-${count.index}"
  }
}

# External HTTPS access - one CIDR per rule
resource "aws_vpc_security_group_ingress_rule" "external_nlb_https_cidrs" {
  count             = local.is_external_access && var.ddc_infra_config != null ? length(var.allowed_external_cidrs) : 0
  security_group_id = aws_security_group.external_nlb_sg[0].id
  description       = "HTTPS access from allowed CIDR ${var.allowed_external_cidrs[count.index]}"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.allowed_external_cidrs[count.index]
  
  tags = {
    Name = "external-nlb-https-${count.index}"
  }
}

# External prefix list HTTP
resource "aws_vpc_security_group_ingress_rule" "external_nlb_http_prefix" {
  count             = local.is_external_access && var.ddc_infra_config != null && var.external_prefix_list_id != null ? 1 : 0
  security_group_id = aws_security_group.external_nlb_sg[0].id
  description       = "HTTP access from managed prefix list"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = var.external_prefix_list_id
  
  tags = {
    Name = "external-nlb-http-prefix"
  }
}

# External prefix list HTTPS
resource "aws_vpc_security_group_ingress_rule" "external_nlb_https_prefix" {
  count             = local.is_external_access && var.ddc_infra_config != null && var.external_prefix_list_id != null ? 1 : 0
  security_group_id = aws_security_group.external_nlb_sg[0].id
  description       = "HTTPS access from managed prefix list"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = var.external_prefix_list_id
  
  tags = {
    Name = "external-nlb-https-prefix"
  }
}

# External egress
resource "aws_vpc_security_group_egress_rule" "external_nlb_egress" {
  count             = local.is_external_access && var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.external_nlb_sg[0].id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  
  tags = {
    Name = "external-nlb-egress-all"
  }
}

################################################################################
# Internal NLB Security Group (Clear and Simple)
################################################################################

resource "aws_security_group" "internal_nlb_sg" {
  count  = !local.is_external_access && var.ddc_infra_config != null ? 1 : 0
  name   = "${var.project_prefix}-internal-nlb-sg"
  vpc_id = var.vpc_id
  
  tags = merge(var.tags, {
    Name   = "${var.project_prefix}-internal-nlb-sg"
    Type   = "Internal NLB"
    Region = var.region
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Internal HTTP access
resource "aws_vpc_security_group_ingress_rule" "internal_nlb_http_vpc" {
  count             = !local.is_external_access && var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.internal_nlb_sg[0].id
  description       = "HTTP access from VPC CIDR"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = data.aws_vpc.main.cidr_block
  
  tags = {
    Name = "internal-nlb-http-vpc"
  }
}

# Internal HTTPS access
resource "aws_vpc_security_group_ingress_rule" "internal_nlb_https_vpc" {
  count             = !local.is_external_access && var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.internal_nlb_sg[0].id
  description       = "HTTPS access from VPC CIDR"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = data.aws_vpc.main.cidr_block
  
  tags = {
    Name = "internal-nlb-https-vpc"
  }
}

# Internal egress
resource "aws_vpc_security_group_egress_rule" "internal_nlb_egress" {
  count             = !local.is_external_access && var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.internal_nlb_sg[0].id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  
  tags = {
    Name = "internal-nlb-egress-all"
  }
}

################################################################################
# Shared Rules for Both External and Internal (DRY where it makes sense)
################################################################################

# Rules from existing security groups (works for both external/internal)
resource "aws_vpc_security_group_ingress_rule" "nlb_from_users" {
  count                        = var.ddc_infra_config != null ? length(var.existing_security_groups) : 0
  security_group_id            = local.is_external_access ? aws_security_group.external_nlb_sg[0].id : aws_security_group.internal_nlb_sg[0].id
  description                  = "DDC traffic from user security group ${var.existing_security_groups[count.index]}"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = var.existing_security_groups[count.index]
  
  tags = {
    Name = "nlb-from-users-${count.index}"
  }
}

# Allow outbound to EKS cluster (works for both external/internal)
resource "aws_vpc_security_group_egress_rule" "nlb_to_cluster" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = local.is_external_access ? aws_security_group.external_nlb_sg[0].id : aws_security_group.internal_nlb_sg[0].id
  description       = "To EKS cluster DDC services"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 8091
  cidr_ipv4         = data.aws_vpc.main.cidr_block
  
  tags = {
    Name = "nlb-to-cluster"
  }
}

# Allow NLB to access EKS cluster (works for both external/internal)
resource "aws_vpc_security_group_ingress_rule" "eks_cluster_from_nlb" {
  count                        = var.ddc_infra_config != null ? 1 : 0
  security_group_id            = module.ddc_infra[0].cluster_security_group_id
  description                  = "Allow traffic from DDC NLB to EKS cluster"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = local.is_external_access ? aws_security_group.external_nlb_sg[0].id : aws_security_group.internal_nlb_sg[0].id
  
  tags = {
    Name = "eks-cluster-from-nlb"
  }
}