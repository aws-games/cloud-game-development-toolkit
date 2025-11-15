################################################################################
# Scylla SG
################################################################################
resource "aws_security_group" "scylla_security_group" {
  region      = var.region
  name        = "${local.name_prefix}-scylla-sg"
  description = "Security group for ScyllaDB"
  vpc_id      = var.vpc_id

  # CRITICAL: Prevents cyclic dependency during destroy
  # This SG has self-referencing rules (referenced_security_group_id = this SG)
  # Creates circular dependency: SG rules depend on SG, but rules reference same SG
  # Without this, Terraform can't determine destroy order and hangs
  revoke_rules_on_delete = true

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
# SSM Egress Rules for Scylla SG
################################################################################
resource "aws_vpc_security_group_egress_rule" "ssm_egress_sg_rules" {
  region            = var.region
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
  region                       = var.region
  security_group_id            = aws_security_group.scylla_security_group.id
  from_port                    = each.value.port
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  referenced_security_group_id = aws_security_group.scylla_security_group.id
  to_port                      = each.value.port
}

################################################################################
# Scylla EKS Cluster Access Rules
################################################################################
# Allow VPC CIDR access to ScyllaDB CQL port for EKS Auto Mode
# EKS Auto Mode manages security groups automatically with timing dependencies
# VPC CIDR is the recommended pattern per AWS documentation for this scenario
resource "aws_vpc_security_group_ingress_rule" "scylla_from_vpc_cql" {
  region            = var.region
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = 9042
  to_port           = 9042
  description       = "ScyllaDB CQL port access from VPC CIDR (EKS Auto Mode standard pattern)"
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.main.cidr_block
}



resource "aws_vpc_security_group_egress_rule" "self_scylla_egress_sg_rules" {
  region                       = var.region
  security_group_id            = aws_security_group.scylla_security_group.id
  from_port                    = 0
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.scylla_security_group.id
  to_port                      = 0
  description                  = "Self SG Egress"
}



################################################################################
# Additional EKS Security Group Rules
################################################################################

# ingress rule allowing ports 80 to 8091 from additional EKS security groups
# Note: cluster_security_group is defined in eks.tf
resource "aws_vpc_security_group_ingress_rule" "cluster_additional_eks_sg_ingress_rule" {
  count                        = length(var.additional_eks_security_groups)
  region                       = var.region
  security_group_id            = aws_security_group.cluster_security_group.id
  description                  = "Allow traffic from additional EKS security groups to DDC services (ports 80-8091)"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = var.additional_eks_security_groups[count.index]
}




