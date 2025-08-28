data "http" "my_ip" {
  url = "https://api.ipify.org"
}

resource "aws_security_group" "allow_my_ip" {
  name_prefix = "${local.project_prefix}-allow-my-ip-"
  vpc_id      = aws_vpc.perforce_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    description = "Perforce"
    from_port   = 1666
    to_port     = 1666
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  # P4 replication traffic within VPC
  ingress {
    description = "P4 Replication within VPC"
    from_port   = 1666
    to_port     = 1666
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.perforce_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.project_prefix}-allow-my-ip"
  }

  lifecycle {
    create_before_destroy = true
  }
}