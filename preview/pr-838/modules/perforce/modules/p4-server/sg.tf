##########################################
# Default SG
##########################################
resource "aws_security_group" "default_security_group" {
  count = var.create_default_sg ? 1 : 0
  #checkov:skip=CKV2_AWS_5:SG is attached to FSxZ file systems

  vpc_id      = var.vpc_id
  name        = "${local.name_prefix}-instance"
  description = "Security group for P4 Server machines."
  tags = merge(local.tags,
    {
      Name = "${local.name_prefix}-instance"
    }
  )
}

# P4 Server --> Internet
# Allows P4 Server to send outbound traffic to the Internet
resource "aws_vpc_security_group_egress_rule" "server_internet" {
  count             = var.create_default_sg ? 1 : 0
  security_group_id = aws_security_group.default_security_group[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
  description       = "Allows P4 Server to send outbound traffic to the Internet."
}
