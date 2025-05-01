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

# Allow port 9180 from monitoring to scylla
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_ingress_prometheus" {
  count                        = var.create_scylla_monitoring_stack ? 1 : 0
  from_port                    = 9180
  to_port                      = 9180
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.scylla_monitoring_sg[count.index].id
  security_group_id            = aws_security_group.scylla_security_group.id
  description                  = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

# Allow port 9100 from monitoring to scylla
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_ingress_node_exporter" {
  count                        = var.create_scylla_monitoring_stack ? 1 : 0
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.scylla_monitoring_sg[count.index].id
  security_group_id            = aws_security_group.scylla_security_group.id
  description                  = "Allow the Scylla monitoring stack to access the cluster using node_exporter"
}

################################################################################
# Scylla Monitoring SG
################################################################################

resource "aws_security_group" "scylla_monitoring_sg" {
  count       = var.create_scylla_monitoring_stack ? 1 : 0
  name        = "${var.name}-scylla-monitoring-sg"
  description = "Scylla monitoring security group"
  vpc_id      = var.vpc_id
  tags = {
    Name = "unreal-cloud-ddc-scylla-monitoring-sg"
  }
  #checkov:skip=CKV2_AWS_5:Security groups are attached to their resources
}

# Allow port 3000 for Grafana from load balancer to monitoring
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_lb_monitoring" {
  count                        = var.create_scylla_monitoring_stack ? 1 : 0
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  security_group_id            = aws_security_group.scylla_monitoring_sg[count.index].id
  referenced_security_group_id = aws_security_group.scylla_monitoring_lb_sg[count.index].id
  description                  = "Allow traffic from the NLB to the Grafana UI"
}

# Scylla monitoring security group egress rule allowing outbound traffic to the internet
resource "aws_vpc_security_group_egress_rule" "scylla_monitoring_sg_egress_rule" {
  count             = var.create_scylla_monitoring_stack ? 1 : 0
  security_group_id = aws_security_group.scylla_monitoring_sg[count.index].id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Scylla monitoring load balancer security group

resource "aws_security_group" "scylla_monitoring_lb_sg" {
  count       = var.create_scylla_monitoring_stack ? 1 : 0
  name        = "${var.name}-scylla-monitoring-lb-sg"
  description = "Scylla monitoring load balancer security group"
  vpc_id      = var.vpc_id
  tags = {
    Name = "unreal-cloud-ddc-scylla-monitoring-lb-sg"
  }
  #checkov:skip=CKV2_AWS_5:Security groups are attached to their resources
  #checkov:skip=CKV_AWS_2:Supporting port 80 for simplicity for now locked down by only leaving it open to the allowlisted IP addresses
}
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_lb_ingress" {
  count             = var.create_scylla_monitoring_stack ? length(var.scylla_monitoring_dashboard_access_cidrs) : 0
  security_group_id = aws_security_group.scylla_monitoring_lb_sg[0].id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.scylla_monitoring_dashboard_access_cidrs[count.index]
  description       = "Allow traffic from allow listed IPs to the NLB"
}

resource "aws_vpc_security_group_egress_rule" "scylla_monitoring_lb_sg_egress_rule" {
  count             = var.create_scylla_monitoring_stack ? 1 : 0
  security_group_id = aws_security_group.scylla_monitoring_lb_sg[count.index].id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
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
