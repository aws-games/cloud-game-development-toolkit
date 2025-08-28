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

# Allow port 9180 from monitoring to scylla
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_ingress_prometheus" {
  count                        = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  from_port                    = 9180
  to_port                      = 9180
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.scylla_monitoring_sg[count.index].id
  security_group_id            = aws_security_group.scylla_security_group.id
  description                  = "Allow the Scylla monitoring stack to access the cluster using Prometheus API"
}

# Allow port 9100 from monitoring to scylla
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_ingress_node_exporter" {
  count                        = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
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
  name        = "${local.name_prefix}-scylla-monitoring-sg"
  description = "Scylla monitoring security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-monitoring-sg"
    }
  )
  #checkov:skip=CKV2_AWS_5:Security groups are attached to their resources
}

# Allow port 3000 for Grafana from load balancer to monitoring
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_lb_monitoring" {
  count                        = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  security_group_id            = aws_security_group.scylla_monitoring_sg[count.index].id
  referenced_security_group_id = aws_security_group.scylla_monitoring_lb_sg[count.index].id
  description                  = "Allow traffic from the ALB to the Grafana UI"
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
  count       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  name        = "${local.name_prefix}-scylla-monitoring-lb-sg"
  description = "Scylla monitoring load balancer security group"
  vpc_id      = var.vpc_id
  tags = {
    Name = "${local.name_prefix}-scylla-monitoring-lb-sg"
  }
  #checkov:skip=CKV2_AWS_5:Security groups are attached to their resources
  #checkov:skip=CKV_AWS_2:Supporting port 80 for simplicity for now locked down by only leaving it open to the allowlisted IP addresses
}

resource "aws_vpc_security_group_egress_rule" "scylla_monitoring_lb_sg_egress_rule" {
  count             = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  security_group_id = aws_security_group.scylla_monitoring_lb_sg[count.index].id
  description       = "Egress for Grafana port"
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 3000
  cidr_ipv4         = "0.0.0.0/0"
}

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
  description = "Security group for nvme node group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-worker-sg"
    }
  )
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

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-system-sg"
    }
  )
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
  description = "Security group for system node group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-cluster-sg"
    }
  )
}

# ingress rule allowing all traffic from self
resource "aws_vpc_security_group_ingress_rule" "self_ingress_cluster_sg_rule" {
  security_group_id            = aws_security_group.cluster_security_group.id
  description                  = "Allow all traffic from any nodes associated with the cluster security group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.cluster_security_group.id
}

# ingress rule allowing ports 80 to 8091 from load balancer sg
resource "aws_vpc_security_group_ingress_rule" "cluster_lb_ingress_sg_rule" {
  #checkov:skip=CKV_AWS_260:This rule only provides this access to the ALB security group which by default allows no inbound access and the user's IP address if allow_my_ip is set to true
  #checkov:skip=CKV_AWS_25:This rule only provides this access to the ALB security group which by default allows no inbound access and the user's IP address if allow_my_ip is set to true
  count                        = length(var.existing_security_groups) > 0 ? 1 : 0
  security_group_id            = aws_security_group.cluster_security_group.id
  description                  = "Allow traffic from ports 80-8091 which is where the target groups sit"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = var.existing_security_groups[count.index]
}

# egress rule allowing all outbound traffic
resource "aws_vpc_security_group_egress_rule" "cluster_egress_sg_rule" {
  security_group_id = aws_security_group.cluster_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
