module "unity_accelerator" {
  source              = "../../"
  vpc_id              = aws_vpc.unity_accelerator_vpc.id
  service_subnets     = aws_subnet.private_subnets[*].id
  lb_subnets          = aws_subnet.public_subnets[*].id
  alb_certificate_arn = aws_acm_certificate.unity_accelerator.arn
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Opening HTTP ingress traffic on Application Load Balancer (redirects to HTTPS)
resource "aws_vpc_security_group_ingress_rule" "unity_accelerator_alb_ingress_http" {
  security_group_id = module.unity_accelerator.alb_security_group_id
  description       = "Allows HTTP traffic (dashboard) from machine IP"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "TCP"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Opening HTTPS ingress traffic on Application Load Balancer
resource "aws_vpc_security_group_ingress_rule" "unity_accelerator_alb_ingress_https" {
  security_group_id = module.unity_accelerator.alb_security_group_id
  description       = "Allows HTTPS traffic (dashboard) from machine IP"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "TCP"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}
