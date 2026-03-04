################################################################################
# NLB Security Group (Standardized)
################################################################################

resource "aws_security_group" "nlb" {
  count  = var.ddc_infra_config != null ? 1 : 0
  name   = "${local.name_prefix}-nlb-${local.name_suffix}"
  vpc_id = var.vpc_id

  # CRITICAL: Ensures clean Terraform destroy by revoking all rules before deletion
  revoke_rules_on_delete = true

  tags = merge(local.default_tags, {
    Name   = "${local.name_prefix}-nlb-${local.name_suffix}"
    Type   = "Network Load Balancer"
    Access = var.load_balancers_config.nlb.internet_facing ? "Internet-facing" : "Internal"
    ManagedBy = "Terraform"
  })
}

# HTTP access from allowed CIDRs
resource "aws_vpc_security_group_ingress_rule" "nlb_http_cidrs" {
  count             = var.ddc_infra_config != null && var.allowed_external_cidrs != null ? length(var.allowed_external_cidrs) : 0
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
  count             = var.ddc_infra_config != null && var.allowed_external_cidrs != null ? length(var.allowed_external_cidrs) : 0
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
  count             = var.ddc_infra_config != null && !var.load_balancers_config.nlb.internet_facing ? 1 : 0
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
  count             = var.ddc_infra_config != null && !var.load_balancers_config.nlb.internet_facing ? 1 : 0
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

# CodeBuild access for functional testing
resource "aws_vpc_security_group_ingress_rule" "nlb_codebuild_http" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "CodeBuild access for DDC functional testing (HTTP)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"  # CodeBuild uses AWS-managed public IPs

  tags = {
    Name = "nlb-codebuild-http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_codebuild_https" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "CodeBuild access for DDC functional testing (HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"  # CodeBuild uses AWS-managed public IPs

  tags = {
    Name = "nlb-codebuild-https"
  }
}

################################################################################
# Internal Service Communication Security Group
################################################################################

resource "aws_security_group" "internal" {
  count  = var.ddc_infra_config != null ? 1 : 0
  name   = "${local.name_prefix}-internal-${local.name_suffix}"
  vpc_id = var.vpc_id

  # CRITICAL: Ensures clean Terraform destroy by revoking all rules before deletion
  revoke_rules_on_delete = true

  tags = merge(local.default_tags, {
    Name        = "${local.name_prefix}-internal-${local.name_suffix}"
    Type        = "Internal Service Communication"
    Description = "Internal communication between DDC services"
    ManagedBy   = "Terraform"
  })
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
  count                        = var.ddc_infra_config != null && var.load_balancers_config.nlb != null ? length(var.load_balancers_config.nlb.security_groups) : 0
  security_group_id            = aws_security_group.nlb[0].id
  description                  = "DDC traffic from user security group ${var.load_balancers_config.nlb.security_groups[count.index]}"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = var.load_balancers_config.nlb.security_groups[count.index]

  tags = {
    Name = "nlb-from-users-${count.index}"
  }
}

# Use VPC CIDR instead of security group references to avoid circular dependencies
# This maintains security while preventing Terraform dependency issues

# NLB to VPC communication (replaces SG reference)
resource "aws_vpc_security_group_egress_rule" "nlb_to_vpc" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.nlb[0].id
  description       = "To VPC for DDC services (ports 80-8091)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 8091
  cidr_ipv4         = data.aws_vpc.main.cidr_block

  tags = {
    Name = "nlb-to-vpc"
  }
}

################################################################################
# EKS Cluster Security Group Rules (for NLB health checks)
################################################################################

# CRITICAL: Allow NLB health checks from VPC CIDR
#
# WHY VPC CIDR INSTEAD OF SECURITY GROUP REFERENCES:
# - AWS Load Balancer Controller creates NLB security group AFTER Terraform apply
# - This creates chicken-and-egg problem: can't reference SG that doesn't exist yet (not in TF state)
# - EKS Auto Mode exacerbates this since cluster and NLB are managed separately
# - VPC CIDR is less restrictive but prevents Terraform dependency cycles
#
# SECURITY TRADE-OFF:
# - More secure: referenced_security_group_id = aws_security_group.nlb[0].id
# - Actually works: cidr_ipv4 = data.aws_vpc.main.cidr_block (this approach)
#
# IMPACT: Allows any resource in VPC to reach EKS cluster on ports 80-8091
# MITIGATION: VPC is private network, pods still have application-level security
resource "aws_vpc_security_group_ingress_rule" "cluster_from_nlb" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = module.ddc_infra.cluster_security_group_id
  description       = "Allow NLB health checks from VPC CIDR (EKS Auto Mode limitation)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 8091
  cidr_ipv4         = data.aws_vpc.main.cidr_block

  tags = {
    Name = "cluster-from-nlb-vpc"
  }
}



