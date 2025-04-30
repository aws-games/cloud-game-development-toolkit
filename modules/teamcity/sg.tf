###################################
# Security Groups                 #
###################################

# TeamCity service security group
resource "aws_security_group" "teamcity_service_sg" {
  name        = "${local.name_prefix}-service-sg"
  vpc_id      = var.vpc_id
  description = "TeamCity service security group"
  tags        = local.tags
}

# TeamCity EFS security group
resource "aws_security_group" "teamcity_efs_sg" {
  count       = var.efs_id == null ? 1 : 0
  name        = "${local.name_prefix}-efs-sg"
  description = "TeamCity EFS mount target security group"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Ingress rule for NFS traffic from service to EFS
resource "aws_vpc_security_group_ingress_rule" "service_efs" {
  count                        = var.efs_id == null ? 1 : 0
  security_group_id            = aws_security_group.teamcity_efs_sg[0].id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow inbound access from TeamCity service containers to EFS"
  ip_protocol                  = "TCP"
  from_port                    = 2049
  to_port                      = 2049
}

# TeamCity Aurora Serverless PostgreSQL security group
resource "aws_security_group" "teamcity_db_sg" {
  count       = var.database_connection_string == null ? 1 : 0
  name        = "${local.name_prefix}-db-sg"
  description = "TeamCity DB security group"
  vpc_id      = var.vpc_id
  tags        = local.tags
}

# Ingress rule for PostgreSQL from service to database cluster
resource "aws_vpc_security_group_ingress_rule" "service_db" {
  count                        = var.database_connection_string == null ? 1 : 0
  security_group_id            = aws_security_group.teamcity_db_sg[0].id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow inbound access from TeamCity service containers to DB"
  ip_protocol                  = "TCP"
  from_port                    = 5432
  to_port                      = 5432
}

# TeamCity ALB security group
resource "aws_security_group" "teamcity_alb_sg" {
  #checkov:skip=CKV2_AWS_5:SG is attached to TeamCity service ALB
  count       = var.create_external_alb ? 1 : 0
  name        = "${local.name_prefix}-alb-sg"
  vpc_id      = var.vpc_id
  description = "TeamCity ALB security group"
  tags        = local.tags
}

# Ingress rule for HTTP traffic from ALB to service
resource "aws_vpc_security_group_ingress_rule" "service_inbound_alb" {
  count                        = var.create_external_alb ? 1 : 0
  security_group_id            = aws_security_group.teamcity_service_sg.id
  referenced_security_group_id = aws_security_group.teamcity_alb_sg[0].id
  description                  = "Allow inbound HTTP traffic from ALB to service containers"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "TCP"
}

# Egress rule for HTTP traffic from ALB to service
resource "aws_vpc_security_group_egress_rule" "alb_outbound_service" {
  count                        = var.create_external_alb ? 1 : 0
  security_group_id            = aws_security_group.teamcity_alb_sg[0].id
  referenced_security_group_id = aws_security_group.teamcity_service_sg.id
  description                  = "Allow outbound HTTP traffic from ALB to service containers"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "TCP"
}

# Grant TeamCity service access to internet
resource "aws_vpc_security_group_egress_rule" "service_outbound_internet" {
  security_group_id = aws_security_group.teamcity_service_sg.id
  description       = "Allow outbound internet access from TeamCity service containers"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}