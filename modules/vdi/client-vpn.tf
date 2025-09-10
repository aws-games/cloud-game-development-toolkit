# AWS Client VPN for private VDI connectivity
# Only created when connectivity_type = "private"

locals {
  # Private users (for generating individual .ovpn files)
  private_users = {
    for user_key, config in var.users :
    user_key => config if config.connectivity_type == "private"
  }
  
  # Enable Client VPN based on root-level flag
  enable_client_vpn = var.enable_private_connectivity
}

##########################################
# Client VPN Server Certificate (Self-signed)
##########################################
resource "tls_private_key" "client_vpn_server" {
  count = local.enable_client_vpn ? 1 : 0
  
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "client_vpn_server" {
  count = local.enable_client_vpn ? 1 : 0
  
  private_key_pem = tls_private_key.client_vpn_server[0].private_key_pem

  subject {
    common_name  = "VDI Client VPN Server"
    organization = "CGD Toolkit"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "client_vpn_server" {
  count = local.enable_client_vpn ? 1 : 0
  
  private_key      = tls_private_key.client_vpn_server[0].private_key_pem
  certificate_body = tls_self_signed_cert.client_vpn_server[0].cert_pem

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-client-vpn-server-cert"
    Purpose = "Client VPN server authentication"
  })
}

##########################################
# Client VPN Client Certificates (Per-User)
##########################################
# Single CA for all users
resource "tls_private_key" "client_vpn_ca" {
  count = local.enable_client_vpn ? 1 : 0
  
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "client_vpn_ca" {
  count = local.enable_client_vpn ? 1 : 0
  
  private_key_pem = tls_private_key.client_vpn_ca[0].private_key_pem

  subject {
    common_name  = "VDI Client VPN CA"
    organization = "CGD Toolkit"
  }

  validity_period_hours = 8760 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
  ]
}

# Per-user client certificates
resource "tls_private_key" "client_vpn_users" {
  for_each = local.enable_client_vpn ? local.private_users : {}
  
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client_vpn_users" {
  for_each = local.enable_client_vpn ? local.private_users : {}
  
  private_key_pem = tls_private_key.client_vpn_users[each.key].private_key_pem

  subject {
    common_name  = "VDI-${each.key}"
    organization = "CGD Toolkit"
  }
}

resource "tls_locally_signed_cert" "client_vpn_users" {
  for_each = local.enable_client_vpn ? local.private_users : {}
  
  cert_request_pem   = tls_cert_request.client_vpn_users[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.client_vpn_ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.client_vpn_ca[0].cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

# Upload CA certificate to ACM (used by VPN endpoint)
resource "aws_acm_certificate" "client_vpn_ca" {
  count = local.enable_client_vpn ? 1 : 0
  
  private_key       = tls_private_key.client_vpn_ca[0].private_key_pem
  certificate_body  = tls_self_signed_cert.client_vpn_ca[0].cert_pem

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-client-vpn-ca-cert"
    Purpose = "Client VPN CA certificate"
  })
}

##########################################
# AWS Client VPN Endpoint
##########################################
resource "aws_ec2_client_vpn_endpoint" "vdi" {
  count = local.enable_client_vpn ? 1 : 0
  
  description            = "VDI Private Access Client VPN"
  server_certificate_arn = aws_acm_certificate.client_vpn_server[0].arn
  client_cidr_block      = var.client_vpn_config.client_cidr_block
  
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_vpn_ca[0].arn
  }

  connection_log_options {
    enabled = false
  }

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-vdi-client-vpn"
  })
}

# Get unique subnets from workstations for VPN associations
locals {
  vpn_subnets = local.enable_client_vpn ? toset([
    for workstation_key, config in var.workstations : config.subnet_id
  ]) : []
}

# Associate VPN with all subnets used by workstations
resource "aws_ec2_client_vpn_network_association" "vdi" {
  for_each = local.vpn_subnets
  
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vdi[0].id
  subnet_id              = each.value
}

# Route to VPC CIDR
resource "aws_ec2_client_vpn_route" "vdi" {
  count = local.enable_client_vpn ? 1 : 0
  
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vdi[0].id
  destination_cidr_block = data.aws_vpc.selected.cidr_block
  target_vpc_subnet_id   = tolist(local.vpn_subnets)[0]
}

# Authorization rule for VPC access
resource "aws_ec2_client_vpn_authorization_rule" "vdi" {
  count = local.enable_client_vpn ? 1 : 0
  
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vdi[0].id
  target_network_cidr    = data.aws_vpc.selected.cidr_block
  authorize_all_groups   = true
}

##########################################
# Generate VPN Client Configuration Files
##########################################
# VPN client config template (generated per user)
# Template will be created when generating .ovpn files

##########################################
# S3 Bucket for VPN Client Configs
##########################################
resource "random_string" "bucket_suffix" {
  count = local.enable_client_vpn ? 1 : 0
  
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "vpn_configs" {
  count = local.enable_client_vpn ? 1 : 0
  
  bucket        = "${var.project_prefix}-vdi-vpn-configs-${random_string.bucket_suffix[0].result}"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-vdi-vpn-configs"
    Purpose = "VPN client configuration files"
  })
}

resource "aws_s3_bucket_public_access_block" "vpn_configs" {
  count = local.enable_client_vpn ? 1 : 0
  
  bucket = aws_s3_bucket.vpn_configs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Store user certificates alongside their .ovpn files
resource "aws_s3_object" "user_certificates" {
  for_each = local.enable_client_vpn ? {
    for workstation_key, assignment in var.workstation_assignments :
    workstation_key => assignment if contains(keys(local.private_users), assignment.user)
  } : {}
  
  bucket  = aws_s3_bucket.vpn_configs[0].id
  key     = "${each.key}-${each.value.user}/${each.key}-${each.value.user}.crt"
  content = tls_locally_signed_cert.client_vpn_users[each.value.user].cert_pem
  
  tags = merge(var.tags, {
    Purpose     = "VPN client certificate"
    Username    = each.value.user
    Workstation = each.key
  })
}

resource "aws_s3_object" "user_private_keys" {
  for_each = local.enable_client_vpn ? {
    for workstation_key, assignment in var.workstation_assignments :
    workstation_key => assignment if contains(keys(local.private_users), assignment.user)
  } : {}
  
  bucket  = aws_s3_bucket.vpn_configs[0].id
  key     = "${each.key}-${each.value.user}/${each.key}-${each.value.user}.key"
  content = tls_private_key.client_vpn_users[each.value.user].private_key_pem
  
  tags = merge(var.tags, {
    Purpose     = "VPN client private key"
    Username    = each.value.user
    Workstation = each.key
  })
}

# Store CA certificate in each user folder for convenience
resource "aws_s3_object" "user_ca_certificates" {
  for_each = local.enable_client_vpn ? {
    for workstation_key, assignment in var.workstation_assignments :
    workstation_key => assignment if contains(keys(local.private_users), assignment.user)
  } : {}
  
  bucket  = aws_s3_bucket.vpn_configs[0].id
  key     = "${each.key}-${each.value.user}/${each.key}-ca.crt"
  content = tls_self_signed_cert.client_vpn_ca[0].cert_pem
  
  tags = merge(var.tags, {
    Purpose     = "VPN CA certificate"
    Username    = each.value.user
    Workstation = each.key
  })
}

##########################################
# Internal DNS for Private Users
##########################################
# Create private hosted zone for internal DNS
resource "aws_route53_zone" "vdi_internal" {
  count = local.enable_client_vpn ? 1 : 0
  
  name = "vdi.internal"
  
  vpc {
    vpc_id = data.aws_vpc.selected.id
  }
  
  tags = merge(var.tags, {
    Name = "${var.project_prefix}-vdi-internal-zone"
    Purpose = "Internal DNS for VDI instances"
  })
}

# DNS records for private users (user-based only)
# Automatically updates when EC2 instances are recreated
resource "aws_route53_record" "vdi_users" {
  for_each = local.enable_client_vpn ? {
    for workstation_key, assignment in var.workstation_assignments :
    assignment.user => workstation_key if contains(keys(local.private_users), assignment.user)
  } : {}
  
  zone_id = aws_route53_zone.vdi_internal[0].zone_id
  name    = "${each.key}.vdi.internal"  # john-doe.vdi.internal
  type    = "A"
  ttl     = 60  # Lower TTL for faster updates
  records = [aws_instance.workstations[each.value].private_ip]  # Dynamic reference
}

# Store VPN client configs in S3 per private user
resource "aws_s3_object" "vpn_client_configs" {
  for_each = local.enable_client_vpn && var.client_vpn_config.generate_client_configs ? {
    for workstation_key, assignment in var.workstation_assignments :
    workstation_key => assignment if contains(keys(local.private_users), assignment.user)
  } : {}
  
  bucket = aws_s3_bucket.vpn_configs[0].id
  key    = "${each.key}-${each.value.user}/${each.key}-${each.value.user}.ovpn"
  
  content = <<-EOF
client
dev tun
proto udp
remote ${aws_ec2_client_vpn_endpoint.vdi[0].dns_name} 443
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
verb 3

<ca>
${tls_self_signed_cert.client_vpn_ca[0].cert_pem}</ca>

<cert>
${tls_locally_signed_cert.client_vpn_users[each.value.user].cert_pem}</cert>

<key>
${tls_private_key.client_vpn_users[each.value.user].private_key_pem}</key>
EOF
  
  tags = merge(var.tags, {
    Purpose      = "VPN client configuration"
    Workstation  = each.key
    Username     = each.value.user
  })
}