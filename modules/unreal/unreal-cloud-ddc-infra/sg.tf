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

resource "aws_security_group_rule" "nvme_egress_sg_rules" {
  security_group_id = aws_security_group.nvme_security_group.id
  from_port         = 0
  description       = "Egress All"
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
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

resource "aws_security_group_rule" "worker_egress_sg_rules" {
  security_group_id = aws_security_group.worker_security_group.id
  from_port         = 0
  description       = "Egress All"
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}


################################################################################
# SSM Egress Rules for Scylla SG
################################################################################
resource "aws_security_group_rule" "ssm_egress_sg_rules" {
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = 0
  description       = "Egress All"
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}



################################################################################
# Scylla Security Group to Self Rules
################################################################################
resource "aws_security_group_rule" "self_ingress_sg_rules" {
  for_each          = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = each.value.port
  description       = each.value.description
  protocol          = each.value.protocol
  self              = true
  to_port           = each.value.port
  type              = "ingress"
}

resource "aws_security_group_rule" "self_scylla_egress_sg_rules" {
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = 0
  protocol          = "tcp"
  self              = true
  to_port           = 0
  type              = "egress"
  description       = "Self SG Egress"
}

################################################################################
# Scylla Security Group to Peer CIDR Rules
################################################################################
resource "aws_security_group_rule" "peer_cidr_blocks_ingress_sg_rules" {
  for_each          = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = each.value.port
  description       = each.value.description
  protocol          = each.value.protocol
  cidr_blocks       = var.peer_cidr_blocks
  to_port           = each.value.port
  type              = "ingress"
}

resource "aws_security_group_rule" "peer_cidr_blocks_scylla_egress_sg_rules" {
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = 0
  protocol          = "tcp"
  cidr_blocks       = var.peer_cidr_blocks
  to_port           = 0
  type              = "egress"
  description       = "Peer block egress"
}


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

resource "aws_security_group_rule" "system_egress_sg_rules" {
  security_group_id = aws_security_group.system_security_group.id
  from_port         = 0
  description       = "Egress All"
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
