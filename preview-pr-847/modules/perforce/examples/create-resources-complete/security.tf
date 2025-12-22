resource "aws_security_group" "allow_my_ip" {
  name        = "allow_my_ip"
  description = "Allow inbound traffic from my IP"
  vpc_id      = aws_vpc.perforce_vpc.id

  tags = {
    Name = "allow_my_ip"
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow HTTPS traffic from my public IP."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow HTTP traffic from my public IP."
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_vpc_security_group_ingress_rule" "allow_icmp" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow ICMP traffic from my public IP."
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}
resource "aws_vpc_security_group_ingress_rule" "allow_perforce" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow Perforce traffic from my public IP."
  from_port         = 1666
  to_port           = 1666
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}
