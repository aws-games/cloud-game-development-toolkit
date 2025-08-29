##########################################
# Security Group for My IP Access
##########################################
resource "aws_security_group" "allow_my_ip" {
  name        = "${local.project_prefix}-allow-my-ip"
  description = "Allow inbound traffic from my IP to DDC and monitoring services"
  vpc_id      = aws_vpc.unreal_cloud_ddc_vpc.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-allow-my-ip"
  })
}

##########################################
# Get My Public IP
##########################################
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

##########################################
# Security Group Rules for My IP
##########################################
# Allow HTTPS access to monitoring dashboard
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow HTTPS traffic from my public IP to monitoring dashboard"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow HTTP access to monitoring dashboard
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow HTTP traffic from my public IP to monitoring dashboard"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow ICMP for troubleshooting
resource "aws_vpc_security_group_ingress_rule" "allow_icmp" {
  security_group_id = aws_security_group.allow_my_ip.id
  description       = "Allow ICMP traffic from my public IP for troubleshooting"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}