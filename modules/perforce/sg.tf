##########################################
# Perforce NLB Security Group
##########################################
resource "aws_security_group" "perforce_network_load_balancer" {
  count       = var.create_default_sgs != false ? 1 : 0
  name        = "${var.project_prefix}-perforce-nlb-sg"
  description = "Perforce Network Load Balancer Security Group"
  vpc_id      = var.vpc_id
  #checkov:skip=CKV2_AWS_5:Security group is attached to Perforce NLB

  tags = merge(var.tags,
    {
      Name = "${var.project_prefix}-perforce-nlb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }

}

##########################################
# Perforce NLB Security Group | Rules
##########################################
# Perforce NLB --> Perforce Web Services ALB
# Allows Perforce NLB to send outbound traffic to Perforce Web Services ALB
resource "aws_vpc_security_group_egress_rule" "perforce_nlb_outbound_to_perforce_web_services_alb" {
  count                        = var.create_default_sgs != false ? 1 : 0
  security_group_id            = aws_security_group.perforce_network_load_balancer[0].id
  description                  = "Allows Perforce NLB to send outbound traffic to Perforce Web Services ALB."
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "TCP"
  referenced_security_group_id = aws_security_group.perforce_web_services_alb[0].id

  tags = merge(var.tags,
    {
      Name = "${var.project_prefix}-perforce-nlb-sg-rule"
    }
  )
}


####################################################
# Perforce Web Services ALB Security Group
###################################################
resource "aws_security_group" "perforce_web_services_alb" {
  count       = var.create_default_sgs != false ? 1 : 0
  name        = "${var.project_prefix}-perforce-web-services-alb-sg"
  description = "Perforce Web Services ALB"
  vpc_id      = var.vpc_id
  #checkov:skip=CKV2_AWS_5:Security group is attached to Perforce Web Services ALB

  tags = merge(var.tags,
    {
      Name = "${var.project_prefix}-perforce-web-services-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

####################################################
# Perforce Web Services ALB Security Group | Rules
####################################################
# Perforce Web Services ALB <-- Perforce NLB
# Allows Perforce Web Services ALB to receive inbound traffic from Perforce NLB.
resource "aws_vpc_security_group_ingress_rule" "perforce_web_services_inbound_from_perforce_nlb" {
  count                        = var.create_default_sgs != false ? 1 : 0
  security_group_id            = aws_security_group.perforce_web_services_alb[0].id
  description                  = "Allows Perforce Web Services ALB to receive inbound traffic from Perforce NLB."
  ip_protocol                  = "TCP"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.perforce_network_load_balancer[0].id
  tags = merge(var.tags,
    {
      Name = "${var.project_prefix}-perforce-web-services-alb-sg-rule"
    }
  )
}

# TODO - Potentially make the following two SG rules for allowing traffic from the public subnets (where the nodes for the public NLB are) to the private subnets (where the nodes for the private ALB are) more dynamic, unless we assume that only 2 subnets would ever be created and used. I believe we can make this assumption, since currently the two ECS services span across two AZs/Subnets. I don't see an immediate need to allow for 4 AZs/Subnets.

# Perforce Web Services ALB <-- Public Subnet 1 (where Perforce NLB is deployed)
# Allows Perforce Web Services ALB to receive inbound traffic from the first public subnets where the Public Perforce NLB is deployed.
resource "aws_vpc_security_group_ingress_rule" "perforce_web_services_inbound_from_perforce_nlb_subnets_1" {
  count = (
    var.create_default_sgs != false && var.public_subnets_cidrs != null || var.create_default_sgs != false && var.private_subnets_cidrs != null
  ? 1 : 0)
  security_group_id = aws_security_group.perforce_web_services_alb[0].id
  description       = "Allows Perforce Web Services ALB to receive inbound traffic from the first subnet where the Perforce NLB is deployed."
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.public_subnets_cidrs[0] != null ? var.public_subnets_cidrs[0] : var.private_subnets_cidrs[0]

  tags = merge(var.tags,
    {
      Name = "${var.project_prefix}-allow-nlb-subnet-1"
    }
  )
}
# Perforce Web Services ALB <-- Public Subnet 2 (where Perforce NLB is deployed)
# Allows Perforce Web Services ALB to receive inbound traffic from the second public subnets where the Public Perforce NLB is deployed.
resource "aws_vpc_security_group_ingress_rule" "perforce_web_services_inbound_from_perforce_nlb_subnets_2" {
  count = (
    var.create_default_sgs != false && var.public_subnets_cidrs != null || var.create_default_sgs != false && var.private_subnets_cidrs != null
  ? 1 : 0)
  security_group_id = aws_security_group.perforce_web_services_alb[0].id
  description       = "Allows Perforce Web Services ALB to receive inbound traffic from the second subnet where the Perforce NLB is deployed."
  ip_protocol       = "TCP"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.public_subnets_cidrs[1] != null ? var.public_subnets_cidrs[1] : var.private_subnets_cidrs[1]

  tags = merge(var.tags,
    {
      Name = "${var.project_prefix}-allow-nlb-subnet-2"
    }
  )
}

# Perforce Web Services ALB <-- P4 Server
# Allows Perforce Web Services ALB to receive inbound traffic from P4 Server (needed for authentication using P4Auth extension)
resource "aws_vpc_security_group_ingress_rule" "perforce_web_services_inbound_from_p4_server" {
  count = (var.create_shared_application_load_balancer != null && var.create_default_sgs != false
  ? 1 : 0)
  security_group_id            = aws_security_group.perforce_web_services_alb[0].id
  description                  = "Allows Perforce Web Services ALB to receive inbound traffic from P4 Server. This is used for authentication using the P4Auth extension."
  ip_protocol                  = "TCP"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = module.p4_server[0].security_group_id
  tags = merge(var.tags,
    {
      Name = "${var.project_prefix}-perforce-web-services-alb-sg-rule"
    }
  )
}

# Perforce Web Services --> P4Auth
# Allows Perforce Web Services ALB to send outbound traffic to P4Auth
resource "aws_vpc_security_group_egress_rule" "perforce_alb_outbound_to_p4_auth" {
  count = (
    var.p4_auth_config != null && var.create_shared_application_load_balancer != null && var.create_default_sgs != false
    ?
  1 : 0)
  security_group_id            = aws_security_group.perforce_web_services_alb[0].id
  description                  = "Allows Perforce Web Services ALB to send outbound traffic to P4Auth."
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "TCP"
  referenced_security_group_id = module.p4_auth[0].service_security_group_id
}

# Perforce Web Services --> P4 Code Review
# Allows Perforce Web Services ALB to send outbound traffic to P4 Code Review
resource "aws_vpc_security_group_egress_rule" "perforce_alb_outbound_to_p4_code_review" {
  count = (
    var.p4_code_review_config != null && var.create_shared_application_load_balancer != null && var.create_default_sgs != false
  ? 1 : 0)
  security_group_id            = aws_security_group.perforce_web_services_alb[0].id
  description                  = "Allows Perforce Web Services ALB to send outbound traffic to P4 Code Review."
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "TCP"
  referenced_security_group_id = module.p4_code_review[0].service_security_group_id
}

#######################################################################################
# P4 Server Security Group | Rules (security group itself is created in the submodule)
#######################################################################################
# P4 Server <-- P4 Code Review
# Allows P4 Server to receive inbound traffic from P4 Code Review
resource "aws_vpc_security_group_ingress_rule" "p4_server_inbound_from_p4_code_review" {
  count                        = var.p4_code_review_config != null && var.create_default_sgs != false ? 1 : 0
  security_group_id            = module.p4_server[0].security_group_id
  description                  = "Allows P4 Server to receive inbound traffic from P4 Code Review."
  ip_protocol                  = "TCP"
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.p4_code_review[0].service_security_group_id
}


############################################################################################
# P4Auth Security Group | Rules (security group itself is created in the submodule)
############################################################################################
# P4Auth <-- Perforce Web Services ALB
# Allows P4Auth to receive inbound traffic from Perforce Web Services ALB.
resource "aws_vpc_security_group_ingress_rule" "p4_auth_inbound_from_perforce_web_services_alb" {
  count                        = var.p4_auth_config != null && var.create_default_sgs != false ? 1 : 0
  security_group_id            = module.p4_auth[0].service_security_group_id
  description                  = "Allows P4Auth to receive inbound traffic from Perforce Web Services ALB."
  ip_protocol                  = "TCP"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.perforce_web_services_alb[0].id
}


############################################################################################
# P4 Code Review Security Group | Rules (security group itself is created in the submodule)
############################################################################################
# P4 Code Review <-- Perforce Web Services
# Allows P4 Code Review to receive inbound traffic from Perforce Web Services ALB
resource "aws_vpc_security_group_ingress_rule" "p4_code_review_inbound_from_perforce_web_services_alb" {
  count                        = var.p4_code_review_config != null && var.create_default_sgs != false ? 1 : 0
  security_group_id            = module.p4_code_review[0].service_security_group_id
  description                  = "Allows P4 Code Review to receive inbound traffic from Perforce Web Services ALB."
  ip_protocol                  = "TCP"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.perforce_web_services_alb[0].id
  #checkov:skip=CKV_AWS_260:Access restricted to Perforce Web Services ALB
}

# P4 Code Review --> P4 Server
# Allows P4 Code Review to send outbound traffic to P4 Server.
resource "aws_vpc_security_group_egress_rule" "p4_code_review_outbound_to_p4_server" {
  count                        = var.p4_code_review_config != null && var.create_default_sgs != false ? 1 : 0
  security_group_id            = module.p4_code_review[0].service_security_group_id
  description                  = "Allows P4 Code Review to send outbound traffic to P4 Server."
  from_port                    = 1666
  to_port                      = 1666
  ip_protocol                  = "TCP"
  referenced_security_group_id = module.p4_server[0].security_group_id
}


# # Outbound from the P4 Code Review Security Group to the P4 Server Security Group
# resource "aws_vpc_security_group_egress_rule" "p4_code_review_outbound_p4_server" {
#   count                        = var.create_default_sgs != false ? 1 : 0
#   security_group_id            = module.p4_code_review[0].service_security_group_id
#   description                  = "P4 Code Review outbound to P4 Server"
#   from_port                    = 1666
#   to_port                      = 1666
#   ip_protocol                  = "TCP"
#   referenced_security_group_id = module.p4_server[0].security_group_id
# }
# # Inbound to the P4 Server Security Group from the P4 Code Review Security Group
# resource "aws_vpc_security_group_ingress_rule" "p4_server_inbound_p4_code_review" {
#   count                        = var.create_default_sgs != false ? 1 : 0
#   security_group_id            = module.p4_server[0].security_group_id
#   description                  = "P4 Code Review inbound to P4 Server"
#   ip_protocol                  = "TCP"
#   from_port                    = 1666
#   to_port                      = 1666
#   referenced_security_group_id = module.p4_code_review[0].service_security_group_id
# }
