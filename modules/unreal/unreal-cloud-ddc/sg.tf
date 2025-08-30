################################################################################
# DDC Network Load Balancer Security Group
################################################################################

resource "aws_security_group" "ddc_nlb" {
  count       = var.ddc_infra_config != null ? 1 : 0
  name_prefix = "${local.name_prefix}-ddc-nlb-sg-"
  description = "DDC Network Load Balancer Security Group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ddc-nlb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# No ingress rules - external access comes from existing_security_groups

# Allow outbound to EKS cluster (ports 80-8091)
resource "aws_vpc_security_group_egress_rule" "ddc_nlb_to_cluster" {
  count             = var.ddc_infra_config != null ? 1 : 0
  security_group_id = aws_security_group.ddc_nlb[0].id
  description       = "To EKS cluster DDC services"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 8091
  cidr_ipv4         = "10.0.0.0/8"
}

################################################################################
# DDC Monitoring ALB Security Group
################################################################################

resource "aws_security_group" "ddc_monitoring_alb" {
  count       = var.ddc_monitoring_config != null && var.ddc_monitoring_config.create_application_load_balancer ? 1 : 0
  name_prefix = "${local.name_prefix}-monitoring-alb-sg-"
  description = "DDC Monitoring Application Load Balancer Security Group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-monitoring-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# No ingress rules - external access comes from existing_security_groups

# Allow outbound to monitoring instances (Grafana port)
resource "aws_vpc_security_group_egress_rule" "ddc_monitoring_alb_to_grafana" {
  count             = var.ddc_monitoring_config != null && var.ddc_monitoring_config.create_application_load_balancer ? 1 : 0
  security_group_id = aws_security_group.ddc_monitoring_alb[0].id
  description       = "To Grafana monitoring instances"
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 3000
  cidr_ipv4         = "0.0.0.0/0"
}