resource "aws_security_group" "unity_license_server_sg" {
  name        = "unity-floating-license-server-sg"
  description = "Allow traffic to Unity License Server"
  vpc_id      = var.vpc_id
  tags = merge(local.tags,
    {
      Name = "cgd-unity-floating-license-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "egress_out_to_world" {
  security_group_id = aws_security_group.unity_license_server_sg.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ingress_from_client_sg" {
  security_group_id            = aws_security_group.unity_license_server_sg.id
  description                  = "Ingress from Unity Client SG"
  ip_protocol                  = "tcp"
  from_port                    = var.unity_license_server_port
  to_port                      = var.unity_license_server_port
  referenced_security_group_id = aws_security_group.unity_license_server_sg.id
}
