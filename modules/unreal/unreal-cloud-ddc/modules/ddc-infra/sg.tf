################################################################################
# Scylla SG
################################################################################
resource "aws_security_group" "scylla_security_group" {
  name        = "${local.name_prefix}-scylla-sg"
  description = "Security group for ScyllaDB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-sg"
    }
  )
}



################################################################################
# Scylla Monitoring SG
################################################################################



################################################################################
# NVME Security Group
################################################################################
resource "aws_security_group" "nvme_security_group" {
  name        = "${local.name_prefix}-nvme-sg"
  description = "Security group for nvme node group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-nvme-sg"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "nvme_egress_sg_rules" {
  security_group_id = aws_security_group.nvme_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
################################################################################
# Worker Security Group
################################################################################
resource "aws_security_group" "worker_security_group" {
  name        = "${local.name_prefix}-worker-sg"
  description = "Security group for worker node group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-worker-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "worker_egress_sg_rules" {
  security_group_id = aws_security_group.worker_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# SSM Egress Rules for Scylla SG
################################################################################
resource "aws_vpc_security_group_egress_rule" "ssm_egress_sg_rules" {
  security_group_id = aws_security_group.scylla_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Scylla Security Group to Self Rules
################################################################################
resource "aws_vpc_security_group_ingress_rule" "self_ingress_sg_rules" {
  for_each                     = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
  security_group_id            = aws_security_group.scylla_security_group.id
  from_port                    = each.value.port
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  referenced_security_group_id = aws_security_group.scylla_security_group.id
  to_port                      = each.value.port
}



resource "aws_vpc_security_group_egress_rule" "self_scylla_egress_sg_rules" {
  security_group_id            = aws_security_group.scylla_security_group.id
  from_port                    = 0
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.scylla_security_group.id
  to_port                      = 0
  description                  = "Self SG Egress"
}

################################################################################
# System Security Group
################################################################################
resource "aws_security_group" "system_security_group" {
  name        = "${local.name_prefix}-system-sg"
  description = "Security group for system node group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-system-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "system_egress_sg_rules" {
  security_group_id = aws_security_group.system_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Cluster Security Group
################################################################################

resource "aws_security_group" "cluster_security_group" {
  name        = "${local.name_prefix}-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cluster-sg"
  })
}

# ingress rule allowing all traffic from self
resource "aws_vpc_security_group_ingress_rule" "self_ingress_cluster_sg_rule" {
  security_group_id            = aws_security_group.cluster_security_group.id
  description                  = "Allow all traffic from any nodes associated with the cluster security group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.cluster_security_group.id
}

# Security group access is now handled at the parent module level via load_balancers_config

# ingress rule allowing ports 80 to 8091 from additional EKS security groups
resource "aws_vpc_security_group_ingress_rule" "cluster_additional_eks_sg_ingress_rule" {
  count                        = length(var.additional_eks_security_groups)
  security_group_id            = aws_security_group.cluster_security_group.id
  description                  = "Allow traffic from additional EKS security groups to DDC services (ports 80-8091)"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = var.additional_eks_security_groups[count.index]
}

# egress rule allowing all outbound traffic
resource "aws_vpc_security_group_egress_rule" "cluster_egress_sg_rule" {
  security_group_id = aws_security_group.cluster_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
