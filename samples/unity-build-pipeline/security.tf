##########################################
# Security Groups
##########################################

# Security group for allowing access from user's IP
resource "aws_security_group" "allow_my_ip" {
  name        = "${local.project_prefix}-allow-my-ip"
  description = "Allow inbound traffic from my IP"
  vpc_id      = aws_vpc.unity_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-allow-my-ip"
  })
}

# Allow HTTPS traffic from user's IP
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow HTTPS traffic from personal IP"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${local.my_ip}/32"
}

# Allow Perforce traffic from user's IP
resource "aws_vpc_security_group_ingress_rule" "allow_perforce" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow Perforce traffic from personal IP"
  from_port         = 1666
  to_port           = 1666
  ip_protocol       = "tcp"
  cidr_ipv4         = "${local.my_ip}/32"
}

# Allow Perforce traffic from VPC (includes TeamCity agents)
resource "aws_vpc_security_group_ingress_rule" "perforce_from_vpc" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow Perforce traffic from VPC (TeamCity agents)"
  from_port         = 1666
  to_port           = 1666
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc_cidr_block
}

##########################################
# Unity License Server Security Rules
##########################################

# Allow HTTP traffic from user's IP to Unity License Server ALB (redirects to HTTPS)
resource "aws_vpc_security_group_ingress_rule" "unity_license_server_http" {
  count             = var.unity_license_server_file_path != null ? 1 : 0
  security_group_id = module.unity_license_server[0].alb_security_group_id
  description       = "Allow HTTP traffic from personal IP (redirects to HTTPS)"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "${local.my_ip}/32"
}

# Allow HTTPS traffic from user's IP to Unity License Server ALB (dashboard access)
resource "aws_vpc_security_group_ingress_rule" "unity_license_server_https" {
  count             = var.unity_license_server_file_path != null ? 1 : 0
  security_group_id = module.unity_license_server[0].alb_security_group_id
  description       = "Allow HTTPS traffic from personal IP for dashboard access"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${local.my_ip}/32"
}

# Allow Unity License Server access from VPC (TeamCity agents and other services)
resource "aws_vpc_security_group_ingress_rule" "unity_license_server_from_vpc" {
  count             = var.unity_license_server_file_path != null ? 1 : 0
  security_group_id = module.unity_license_server[0].created_unity_license_server_security_group_id
  description       = "Allow Unity License Server access from VPC (build agents)"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc_cidr_block
}
