################################################################################
# Scylla Monitoring Security Group
################################################################################

resource "aws_security_group" "scylla_monitoring_sg" {
  count       = var.create_scylla_monitoring_stack ? 1 : 0
  name        = "${local.name_prefix}-scylla-monitoring-sg"
  description = "Scylla monitoring security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-monitoring-sg"
  })
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

################################################################################
# Scylla Monitoring Load Balancer Security Group
################################################################################

resource "aws_security_group" "scylla_monitoring_lb_sg" {
  count       = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  name        = "${local.name_prefix}-scylla-monitoring-lb-sg"
  description = "Scylla monitoring load balancer security group"
  vpc_id      = var.vpc_id
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-scylla-monitoring-lb-sg"
  })
}

# Allow HTTPS traffic from internet to ALB
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_lb_https_ingress" {
  count             = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  security_group_id = aws_security_group.scylla_monitoring_lb_sg[count.index].id
  description       = "HTTPS from internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow HTTP traffic from internet to ALB (for redirect)
resource "aws_vpc_security_group_ingress_rule" "scylla_monitoring_lb_http_ingress" {
  count             = var.create_scylla_monitoring_stack && var.create_application_load_balancer ? 1 : 0
  security_group_id = aws_security_group.scylla_monitoring_lb_sg[count.index].id
  description       = "HTTP from internet (redirect to HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
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