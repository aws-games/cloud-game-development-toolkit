# AWS Client VPN for private VDI connectivity
# Only created when create_client_vpn = true and users have use_client_vpn = true

locals {
  # Private users (for generating individual .ovpn files)
  private_users = {
    for user_key, config in var.users :
    user_key => config if config.use_client_vpn == true
  }

  # Enable Client VPN based on root-level flag
  enable_client_vpn = var.create_client_vpn
}

##########################################
# Client VPN Server Certificate (Self-signed)
##########################################
resource "tls_private_key" "client_vpn_server" {
  count = local.enable_client_vpn ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

# Server certificate request (to be signed by CA)
resource "tls_cert_request" "client_vpn_server" {
  count = local.enable_client_vpn ? 1 : 0

  private_key_pem = tls_private_key.client_vpn_server[0].private_key_pem

  subject {
    common_name         = "*.cvpn-endpoint.prod.clientvpn.${data.aws_region.current.region}.amazonaws.com"
    organization        = "CGD Toolkit"
    organizational_unit = "VPN Services"
    country             = "US"
  }

  # CRITICAL: Add SAN for modern TLS validation
  dns_names = [
    "*.cvpn-endpoint.prod.clientvpn.${data.aws_region.current.region}.amazonaws.com"
  ]
}

# Server certificate signed by the same CA as client certificates
resource "tls_locally_signed_cert" "client_vpn_server" {
  count = local.enable_client_vpn ? 1 : 0

  cert_request_pem   = tls_cert_request.client_vpn_server[0].cert_request_pem
  ca_private_key_pem = tls_private_key.client_vpn_ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.client_vpn_ca[0].cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "server_auth",
    "digital_signature",
    "key_encipherment",
  ]
}

resource "aws_acm_certificate" "client_vpn_server" {
  #checkov:skip=CKV_AWS_233:Create before destroy not needed for VPN server certificates - managed lifecycle
  count = local.enable_client_vpn ? 1 : 0

  private_key       = tls_private_key.client_vpn_server[0].private_key_pem
  certificate_body  = tls_locally_signed_cert.client_vpn_server[0].cert_pem
  certificate_chain = tls_self_signed_cert.client_vpn_ca[0].cert_pem

  tags = merge(var.tags, {
    Name    = "${var.project_prefix}-client-vpn-server-cert"
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
    common_name         = "VDI Client VPN CA"
    organization        = "CGD Toolkit"
    organizational_unit = "VPN Services"
    country             = "US"
  }

  validity_period_hours = 8760 # 1 year
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "crl_signing",
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
  #checkov:skip=CKV_AWS_233:Create before destroy not needed for VPN CA certificates - managed lifecycle
  count = local.enable_client_vpn ? 1 : 0

  private_key      = tls_private_key.client_vpn_ca[0].private_key_pem
  certificate_body = tls_self_signed_cert.client_vpn_ca[0].cert_pem

  tags = merge(var.tags, {
    Name    = "${var.project_prefix}-client-vpn-ca-cert"
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
  split_tunnel           = var.client_vpn_config.split_tunnel
  dns_servers            = [cidrhost(data.aws_vpc.selected.cidr_block, 2)] # VPC DNS server

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_vpn_ca[0].arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn_logs[0].name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn_logs[0].name
  }

  tags = merge(var.tags, {
    Name = "${var.project_prefix}-vdi-client-vpn"
  })
}

# Get unique subnets from workstations for VPN associations
locals {
  vpn_subnets = local.enable_client_vpn ? {
    for workstation_key, config in var.workstations : workstation_key => config.subnet_id
  } : {}
}

# Associate VPN with all subnets used by workstations
resource "aws_ec2_client_vpn_network_association" "vdi" {
  for_each = local.vpn_subnets

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vdi[0].id
  subnet_id              = each.value
}

# Note: VPC CIDR route is automatically created by Client VPN when network associations are added
# No manual route needed for VPC access

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
  #checkov:skip=CKV_AWS_18:Access logging not required for VPN configs bucket
  #checkov:skip=CKV2_AWS_61:Lifecycle policy not needed - VPN configs should be retained
  #checkov:skip=CKV2_AWS_62:Event notifications not required for VPN configs bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication not required for VPN configs
  #checkov:skip=CKV_AWS_21:Versioning not required for VPN config files
  #checkov:skip=CKV_AWS_145:KMS encryption not required for VPN configs - default encryption sufficient
  #checkov:skip=CKV2_AWS_6:Public access block is configured separately in aws_s3_bucket_public_access_block resource
  count = local.enable_client_vpn ? 1 : 0

  bucket        = "${var.project_prefix}-vdi-vpn-configs-${random_string.bucket_suffix[0].result}"
  force_destroy = true

  tags = merge(var.tags, {
    Name    = "${var.project_prefix}-vdi-vpn-configs"
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
  for_each = local.enable_client_vpn ? local.private_users : {}

  bucket  = aws_s3_bucket.vpn_configs[0].id
  key     = "${each.key}/${each.key}.crt"
  content = tls_locally_signed_cert.client_vpn_users[each.key].cert_pem

  tags = {
    Purpose  = "VPN client certificate"
    Username = each.key
  }
}

resource "aws_s3_object" "user_private_keys" {
  for_each = local.enable_client_vpn ? local.private_users : {}

  bucket  = aws_s3_bucket.vpn_configs[0].id
  key     = "${each.key}/${each.key}.key"
  content = tls_private_key.client_vpn_users[each.key].private_key_pem

  tags = {
    Purpose  = "VPN client private key"
    Username = each.key
  }
}

# Store CA certificate in each user folder for convenience
resource "aws_s3_object" "user_ca_certificates" {
  for_each = local.enable_client_vpn ? local.private_users : {}

  bucket  = aws_s3_bucket.vpn_configs[0].id
  key     = "${each.key}/ca.crt"
  content = tls_self_signed_cert.client_vpn_ca[0].cert_pem

  tags = {
    Purpose  = "VPN CA certificate"
    Username = each.key
  }
}

# CloudWatch Log Group for Client VPN connection logs
resource "aws_cloudwatch_log_group" "client_vpn_logs" {
  #checkov:skip=CKV_AWS_338:1 year log retention not required for VPN connection logs - 7 days sufficient
  #checkov:skip=CKV_AWS_158:KMS encryption not required for VPN connection logs - default encryption sufficient
  count = local.enable_client_vpn ? 1 : 0

  name              = "/aws/clientvpn/${var.project_prefix}-vdi"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name    = "${var.project_prefix}-client-vpn-logs"
    Purpose = "Client VPN connection logs"
  })
}

resource "aws_cloudwatch_log_stream" "client_vpn_logs" {
  count = local.enable_client_vpn ? 1 : 0

  name           = "connection-log"
  log_group_name = aws_cloudwatch_log_group.client_vpn_logs[0].name
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
    Name    = "${var.project_prefix}-vdi-internal-zone"
    Purpose = "Internal DNS for VDI instances"
  })
}



# Store VPN client configs in S3 per private user
resource "aws_s3_object" "vpn_client_configs" {
  for_each = local.enable_client_vpn && var.client_vpn_config.generate_client_configs ? local.private_users : {}

  bucket = aws_s3_bucket.vpn_configs[0].id
  key    = "${each.key}/${each.key}.ovpn"

  content = <<-EOF
client
dev tun
proto udp
remote ${replace(aws_ec2_client_vpn_endpoint.vdi[0].dns_name, "*", "client")} 443
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
${tls_locally_signed_cert.client_vpn_users[each.key].cert_pem}</cert>

<key>
${tls_private_key.client_vpn_users[each.key].private_key_pem}</key>
EOF

  tags = {
    Purpose  = "VPN client configuration"
    Username = each.key
  }
}
