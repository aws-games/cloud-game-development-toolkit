# Public NLB Security Group
resource "aws_security_group" "public_network_load_balancer" {
  name        = "${local.project_prefix}-public-nlb"
  description = "Security group attached to the public NLB."
  vpc_id      = aws_vpc.build_pipeline_vpc.id
  tags        = local.tags
}

# Internal shared ALB Security Group
resource "aws_security_group" "internal_shared_application_load_balancer" {
  name        = "${local.project_prefix}-internal-shared-alb"
  description = "Security group attached to the internal shared ALB."
  vpc_id      = aws_vpc.build_pipeline_vpc.id
  tags        = local.tags
}

# Grant outbound 443 access from public NLB to shared internal ALB
resource "aws_vpc_security_group_egress_rule" "public_nlb_https_to_internal_alb" {
  ip_protocol                  = "TCP"
  security_group_id            = aws_security_group.public_network_load_balancer.id
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.internal_shared_application_load_balancer.id
  description                  = "Allows HTTPS access to internal shared ALB from public NLB."
}

# Grant ingress 443 access from public NLB to shared internal ALB
resource "aws_vpc_security_group_ingress_rule" "internal_alb_https_from_public_nlb" {
  ip_protocol                  = "TCP"
  security_group_id            = aws_security_group.internal_shared_application_load_balancer.id
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.public_network_load_balancer.id
  description                  = "Allows HTTPS access to internal shared ALB from public NLB."
}

# Grant inbound HTTPS access from P4 Server to Shared ALB
resource "aws_vpc_security_group_ingress_rule" "internal_alb_https_from_p4_server" {
  ip_protocol                  = "TCP"
  security_group_id            = aws_security_group.internal_shared_application_load_balancer.id
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = module.terraform-aws-perforce.p4_server_security_group_id
  description                  = "Allows HTTPS access to internal shared ALB from P4 Server."
}

# Grant outbound HTTP access from shared internal ALB to Jenkins service
resource "aws_vpc_security_group_egress_rule" "internal_alb_http_to_jenkins" {
  ip_protocol                  = "TCP"
  security_group_id            = aws_security_group.internal_shared_application_load_balancer.id
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = module.jenkins.service_security_group_id
  description                  = "Allows HTTP access to Jenkins service from internal shared ALB."
}

# Grant inbound HTTP access from shared internal ALB to Jenkins service
resource "aws_vpc_security_group_ingress_rule" "jenkins_http_from_internal_alb" {
  # checkov:skip=CKV_AWS_260: False positive. Restricts access to referenced security group.
  ip_protocol                  = "TCP"
  security_group_id            = module.jenkins.service_security_group_id
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.internal_shared_application_load_balancer.id
  description                  = "Allows HTTP access to Jenkins service from internal shared ALB."
}

# Grant outbound HTTP access from shared internal ALB to P4 Auth service
resource "aws_vpc_security_group_egress_rule" "internal_alb_http_to_p4_auth" {
  ip_protocol                  = "TCP"
  security_group_id            = aws_security_group.internal_shared_application_load_balancer.id
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = module.terraform-aws-perforce.p4_auth_service_security_group_id
  description                  = "Allows HTTP access to P4 Auth service from internal shared ALB."
}

# Grant inbound HTTP access from shared internal ALB to P4 Auth Service
resource "aws_vpc_security_group_ingress_rule" "p4_auth_http_from_internal_alb" {
  # checkov:skip=CKV_AWS_260: False positive. Restricts access to referenced security group.
  ip_protocol                  = "TCP"
  security_group_id            = module.terraform-aws-perforce.p4_auth_service_security_group_id
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = aws_security_group.internal_shared_application_load_balancer.id
  description                  = "Allows HTTP access to P4 Auth service from internal shared ALB."
}

# Grant outbound HTTP access from shared internal ALB to P4 Code Review service
resource "aws_vpc_security_group_egress_rule" "internal_alb_http_to_p4_code_review" {
  ip_protocol                  = "TCP"
  security_group_id            = aws_security_group.internal_shared_application_load_balancer.id
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = module.terraform-aws-perforce.p4_code_review_service_security_group_id
  description                  = "Allows HTTP access to P4 Code Review service from internal shared ALB."
}

# Grant inbound HTTP access from shared internal ALB to P4 Code Review servic
resource "aws_vpc_security_group_ingress_rule" "p4_code_review_http_from_internal_alb" {
  # checkov:skip=CKV_AWS_260: False positive. Restricts access to referenced security group.
  ip_protocol                  = "TCP"
  security_group_id            = module.terraform-aws-perforce.p4_code_review_service_security_group_id
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.internal_shared_application_load_balancer.id
  description                  = "Allows HTTP access to P4 Code Review service from internal shared ALB."
}

# Grant inbound access to P4 server from Jenkins build farm
resource "aws_vpc_security_group_ingress_rule" "p4_server_from_jenkins_build_farm" {
  ip_protocol                  = "TCP"
  security_group_id            = module.terraform-aws-perforce.p4_server_security_group_id
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.jenkins.build_farm_security_group_id
  description                  = "Allows access to P4 server from Jenkins build farm."
}

# Grant inbound access to P4 Server from Jenkins service
resource "aws_vpc_security_group_ingress_rule" "p4_server_from_jenkins_service" {
  ip_protocol                  = "TCP"
  security_group_id            = module.terraform-aws-perforce.p4_server_security_group_id
  from_port                    = 1666
  to_port                      = 1666
  referenced_security_group_id = module.jenkins.service_security_group_id
  description                  = "Allows access to P4 server from Jenkins service."
}

# Security group
resource "aws_security_group" "allow_my_ip" {
  name        = "allow_my_ip"
  description = "Allow inbound traffic from my IP"
  vpc_id      = aws_vpc.build_pipeline_vpc.id

  tags = {
    Name = "allow_my_ip"
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow HTTPS traffic from personal IP."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_perforce" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow Perforce traffic from personal IP."
  from_port         = 1666
  to_port           = 1666
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}
