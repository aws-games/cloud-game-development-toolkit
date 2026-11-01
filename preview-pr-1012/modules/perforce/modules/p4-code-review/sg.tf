########################################
# ALB Security Group
########################################
# Load Balancer Security Group (attached to ALB)
resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5: Attached to ALB on creation
  count       = var.create_application_load_balancer ? 1 : 0
  name        = "${local.name_prefix}-alb"
  vpc_id      = var.vpc_id
  description = "${local.name_prefix} ALB Security Group"
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-alb"
    }
  )
}

# Inbound HTTPS access to ALB from Application
# Required for Swarm instance to validate itself via external URL when P4 server extension connects back
resource "aws_vpc_security_group_ingress_rule" "alb_inbound_from_application" {
  count                        = var.create_application_load_balancer ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  description                  = "Allow HTTPS from ${local.name_prefix} application for self-validation"
  referenced_security_group_id = aws_security_group.application.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# Outbound access from ALB to Application
resource "aws_vpc_security_group_egress_rule" "alb_outbound_to_application" {
  count                        = var.create_application_load_balancer ? 1 : 0
  security_group_id            = aws_security_group.alb[0].id
  description                  = "Allow outbound traffic from ALB to ${local.name_prefix} application"
  referenced_security_group_id = aws_security_group.application.id
  from_port                    = local.application_port
  to_port                      = local.application_port
  ip_protocol                  = "tcp"
}

########################################
# Application Security Group
########################################
# Application Security Group (attached to EC2 instances)
resource "aws_security_group" "application" {
  name        = "${local.name_prefix}-application"
  vpc_id      = var.vpc_id
  description = "${local.name_prefix} application Security Group"
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-application"
    }
  )
}

# Inbound access to Application from ALB
resource "aws_vpc_security_group_ingress_rule" "application_inbound_alb" {
  count                        = var.create_application_load_balancer ? 1 : 0
  security_group_id            = aws_security_group.application.id
  description                  = "Allow inbound traffic from ${local.name_prefix} ALB to ${local.name_prefix} application"
  referenced_security_group_id = aws_security_group.alb[0].id
  from_port                    = local.application_port
  to_port                      = local.application_port
  ip_protocol                  = "tcp"
}

# Outbound access from Application to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "application_outbound_to_internet_ipv4" {
  security_group_id = aws_security_group.application.id
  description       = "Allow outbound traffic from ${local.name_prefix} application to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Application to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "application_outbound_to_internet_ipv6" {
  security_group_id = aws_security_group.application.id
  description       = "Allow outbound traffic from ${local.name_prefix} application to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


########################################
# Elasticache Redis Security Group
########################################
resource "aws_security_group" "elasticache" {
  count = var.existing_redis_connection != null ? 0 : 1
  #checkov:skip=CKV2_AWS_5:Security group is attached to Elasticache cluster
  name        = "${local.name_prefix}-elasticache"
  vpc_id      = var.vpc_id
  description = "${local.name_prefix} Elasticache Redis Security Group"
  tags        = var.tags
}
resource "aws_vpc_security_group_ingress_rule" "elasticache_inbound_from_application" {
  count                        = var.existing_redis_connection != null ? 0 : 1
  security_group_id            = aws_security_group.elasticache[0].id
  description                  = "Allow inbound traffic from P4 Code Review to Redis"
  referenced_security_group_id = aws_security_group.application.id
  from_port                    = local.elasticache_redis_port
  to_port                      = local.elasticache_redis_port
  ip_protocol                  = "tcp"
}


########################################
# EC2 Instance Security Group
########################################
resource "aws_security_group" "ec2_instance" {
  #checkov:skip=CKV2_AWS_5:Security group is attached to EC2 instances in Auto Scaling Group
  name        = "${local.name_prefix}-ec2-instance"
  vpc_id      = var.vpc_id
  description = "${local.name_prefix} EC2 Instance Security Group"
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-ec2-instance"
    }
  )
}

# Outbound access to Internet (IPV4) - Required for AWS API calls and package downloads
resource "aws_vpc_security_group_egress_rule" "ec2_instance_outbound_to_internet_ipv4" {
  security_group_id = aws_security_group.ec2_instance.id
  description       = "Allow outbound traffic from ${local.name_prefix} EC2 instance to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Outbound access to Internet (IPV6) - Required for AWS API calls and package downloads
resource "aws_vpc_security_group_egress_rule" "ec2_instance_outbound_to_internet_ipv6" {
  security_group_id = aws_security_group.ec2_instance.id
  description       = "Allow outbound traffic from ${local.name_prefix} EC2 instance to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}
