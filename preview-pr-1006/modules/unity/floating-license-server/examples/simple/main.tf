module "unity_license_server" {
  source                         = "../../"
  name                           = var.name
  unity_license_server_file_path = var.unity_license_server_file_path
  vpc_id                         = aws_vpc.unity_license_server_vpc.id
  vpc_subnet                     = aws_subnet.private_subnets[0].id
  add_eni_public_ip              = false
  alb_subnets                    = aws_subnet.public_subnets[*].id
  alb_certificate_arn            = aws_acm_certificate.unity_license_server.arn
  enable_alb_deletion_protection = false

  depends_on = [
    aws_nat_gateway.nat_gateway,
    aws_route.private_rt_nat_gateway,
    aws_eip.nat_gateway_eip,
    aws_route_table.private_rt,
    aws_route_table.public_rt,
    aws_route_table_association.private_rt_asso,
    aws_route_table_association.public_rt_asso
  ]
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Opening HTTP ingress traffic on Application Load Balancer (redirects to HTTPS)
resource "aws_vpc_security_group_ingress_rule" "ingress_from_client_http" {
  security_group_id = module.unity_license_server.alb_security_group_id
  description       = "HTTP ingress from local machine for testing."
  ip_protocol       = "TCP"
  from_port         = module.unity_license_server.unity_license_server_port
  to_port           = module.unity_license_server.unity_license_server_port
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Opening HTTPS ingress traffic on Application Load Balancer
resource "aws_vpc_security_group_ingress_rule" "ingress_from_client_https" {
  security_group_id = module.unity_license_server.alb_security_group_id
  description       = "HTTPS ingress from local machine for testing."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "TCP"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}
