################################################################################
# Scylla SG
################################################################################
resource "aws_security_group" "scylla_security_group" {
  name        = "${var.name}-scylla-sg"
  description = "Security group for ScyllaDB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "unreal-cloud-ddc-scylla-sg"
  }
}
################################################################################
# NVME Security Group
################################################################################
resource "aws_security_group" "nvme_security_group" {
  name        = "${var.name}-nvme-sg"
  description = "Security group for nvme node group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "unreal-cloud-ddc-nvme-sg"
  }
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
  name        = "${var.name}-worker-sg"
  description = "Security group for nvme node group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "unreal-cloud-ddc-worker-sg"
  }
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
# Scylla Security Group to Peer CIDR Rules
################################################################################
# resource "aws_vpc_security_group_ingress_rule" "peer_cidr_blocks_ingress_sg_rules" {
#   for_each          = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
#   security_group_id = aws_security_group.scylla_security_group.id
#   from_port         = each.value.port
#   description       = each.value.description
#   ip_protocol       = each.value.protocol
#   cidr_ipv4         = var.peer_cidr_blocks
#   to_port           = each.value.port
# }
#
# resource "aws_vpc_security_group_egress_rule" "peer_cidr_blocks_scylla_egress_sg_rules" {
#   security_group_id = aws_security_group.scylla_security_group.id
#   from_port         = 0
#   ip_protocol       = "tcp"
#   cidr_ipv4         = var.peer_cidr_blocks
#   to_port           = 0
#   description       = "Peer block egress"
# }


################################################################################
# System Security Group
################################################################################
resource "aws_security_group" "system_security_group" {
  name        = "${var.name}-system-sg"
  description = "Security group for system node group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "unreal-cloud-ddc-system-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "system_egress_sg_rules" {
  security_group_id = aws_security_group.system_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
