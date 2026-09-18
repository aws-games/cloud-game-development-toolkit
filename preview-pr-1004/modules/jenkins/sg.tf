########################################
# JENKINS LOAD BALANCER SECURITY GROUP
########################################

# Jenkins Load Balancer Security Group (attached to ALB)
resource "aws_security_group" "jenkins_alb_sg" {
  # checkov:skip=CKV2_AWS_5: False-positive, SG is attached to ALB
  count       = var.create_application_load_balancer ? 1 : 0
  name        = "${local.name_prefix}-ALB"
  vpc_id      = var.vpc_id
  description = "Jenkins ALB Security Group"
  tags        = local.tags
}

# Outbound access from ALB to Containers
resource "aws_vpc_security_group_egress_rule" "jenkins_alb_outbound_service" {
  count                        = var.create_application_load_balancer ? 1 : 0
  security_group_id            = aws_security_group.jenkins_alb_sg[0].id
  description                  = "Allow outbound traffic from Jenkins ALB to Jenkins service"
  referenced_security_group_id = aws_security_group.jenkins_service_sg.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

########################################
# JENKINS SERVICE SECURITY GROUP
########################################

# Jenkins Service Security Group (attached to containers)
resource "aws_security_group" "jenkins_service_sg" {
  name        = "${local.name_prefix}-service"
  vpc_id      = var.vpc_id
  description = "Jenkins Service Security Group"
  tags        = local.tags
}

# Outbound access from Containers to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "jenkins_service_outbound_ipv4" {
  security_group_id = aws_security_group.jenkins_service_sg.id
  description       = "Allow outbound traffic from Jenkins service to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Containers to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "jenkins_service_outbound_ipv6" {
  security_group_id = aws_security_group.jenkins_service_sg.id
  description       = "Allow outbound traffic from Jenkins service to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Inbound access to Containers from ALB
resource "aws_vpc_security_group_ingress_rule" "jenkins_service_inbound_alb" {
  count                        = var.create_application_load_balancer ? 1 : 0
  security_group_id            = aws_security_group.jenkins_service_sg.id
  description                  = "Allow inbound traffic from Jenkins ALB to service"
  referenced_security_group_id = aws_security_group.jenkins_alb_sg[0].id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}


########################################
# JENKINS FILE SYSTEM SECURITY GROUP
########################################

resource "aws_security_group" "jenkins_efs_security_group" {
  name        = "${local.name_prefix}-efs"
  vpc_id      = var.vpc_id
  description = "Jenkins EFS mount target Security Group"
  tags        = local.tags
}

# Inbound access from Service to EFS mount targets
resource "aws_vpc_security_group_ingress_rule" "jenkins_efs_inbound_service" {
  security_group_id            = aws_security_group.jenkins_efs_security_group.id
  description                  = "Allow inbound access from Jenkins service containers to EFS."
  referenced_security_group_id = aws_security_group.jenkins_service_sg.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

########################################
# JENKINS BUILD FARM ASG SECURITY GROUP
########################################


# Jenkins Build Farm Security Group attached to ASGs
resource "aws_security_group" "jenkins_build_farm_sg" {
  name        = "${local.name_prefix}-build-farm"
  vpc_id      = var.vpc_id
  description = "Jenkins Build Farm Compute Security Group"
  tags        = local.tags
}


# Inbound access to Build Farm from Service
resource "aws_vpc_security_group_ingress_rule" "jenkins_build_farm_inbound_ssh_service" {
  security_group_id = aws_security_group.jenkins_build_farm_sg.id
  description       = "Allow inbound traffic from Jenkins service to Build Farm instance."
  #checkov:skip=CKV_AWS_24:Access is restricted to the Jenkins service.

  referenced_security_group_id = aws_security_group.jenkins_service_sg.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

# Outbound access from Build Farm to Internet (IPV4)
resource "aws_vpc_security_group_egress_rule" "jenkins_build_farm_outbound_ipv4" {
  security_group_id = aws_security_group.jenkins_build_farm_sg.id
  description       = "Allow outbound traffic from Jenkins build farm to internet (ipv4)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Outbound access from Build Farm to Internet (IPV6)
resource "aws_vpc_security_group_egress_rule" "jenkins_build_farm_outbound_ipv6" {
  security_group_id = aws_security_group.jenkins_build_farm_sg.id
  description       = "Allow outbound traffic from Jenkins build farm to internet (ipv6)"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

########################################
# JENKINS BUILD FARM FSX SECURITY GROUP
########################################

# Jenkins Build Farm Security Group attached to FSx OpenZFS File Systems
resource "aws_security_group" "jenkins_build_storage_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attahced to FSxZ file systems
  name        = "${local.name_prefix}-build-storage-fsx"
  vpc_id      = var.vpc_id
  description = "Jenkins Build Storage Security Group"
  tags        = local.tags
}


# Inbound access to Build Farm from Service
resource "aws_vpc_security_group_ingress_rule" "jenkins_build_vpc_all_traffic" {
  security_group_id = aws_security_group.jenkins_build_storage_sg.id
  description       = "Allow inbound traffic from Build Farm instance to OpenZFS."
  cidr_ipv4         = data.aws_vpc.build_farm_vpc.cidr_block
  ip_protocol       = "-1" # semantically equivalent to all ports
}
