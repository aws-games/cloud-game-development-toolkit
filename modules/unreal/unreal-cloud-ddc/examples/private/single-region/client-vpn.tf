# AWS Client VPN for private connectivity to DDC resources

resource "aws_ec2_client_vpn_endpoint" "ddc" {
  description            = "${local.project_prefix}-${local.environment}-ddc-client-vpn"
  server_certificate_arn = aws_acm_certificate.ddc.arn
  client_cidr_block     = "172.31.0.0/22"  # VPN client IP range (avoids common overlaps)
  security_group_ids     = [aws_security_group.client_vpn.id]
  
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.ddc.arn  # Using same cert for simplicity
  }
  
  connection_log_options {
    enabled = false
  }
  
  tags = merge(local.tags, {
    Name = "${local.project_prefix}-${local.environment}-ddc-client-vpn"
  })
}

# Associate VPN with private subnets for DDC access
resource "aws_ec2_client_vpn_network_association" "ddc" {
  count                  = length(aws_subnet.private_subnets)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.ddc.id
  subnet_id              = aws_subnet.private_subnets[count.index].id
}

# Authorization rule - allow VPN clients to access VPC resources
resource "aws_ec2_client_vpn_authorization_rule" "ddc" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.ddc.id
  target_network_cidr    = local.vpc_cidr
  authorize_all_groups   = true
}

# Security group for VPN clients
resource "aws_security_group" "client_vpn" {
  name_prefix = "${local.project_prefix}-${local.environment}-client-vpn-"
  vpc_id      = aws_vpc.unreal_cloud_ddc_vpc.id
  
  tags = merge(local.tags, {
    Name = "${local.project_prefix}-${local.environment}-client-vpn-sg"
  })
}

# Egress rule for VPN endpoint ENI to reach EKS API via VPC endpoint
resource "aws_security_group_rule" "client_vpn_egress" {
  type              = "egress"
  from_port         = 443   # EKS API port via VPC endpoint
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [local.vpc_cidr]
  security_group_id = aws_security_group.client_vpn.id
}