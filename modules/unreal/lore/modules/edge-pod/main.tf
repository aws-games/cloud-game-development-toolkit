data "aws_region" "current" {}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${local.is_arm64 ? "arm64" : "x86_64"}"
}

locals {
  instance_family = split(".", var.instance_type)[0]
  is_arm64        = contains(["c9gd", "c9g", "c8gd", "c8g", "c7gd", "c7g", "c7gn", "m7g", "m7gd", "m8g", "m8gd", "r7g", "r7gd", "r8g", "r8gd", "t4g", "im4gn", "is4gen", "x2gd", "hpc7g"], local.instance_family)
  ecr_region      = data.aws_region.current.region
  ecr_registry    = split("/", var.container_image)[0]
  hmac_key        = var.hmac_key != null ? var.hmac_key : random_id.hmac[0].hex

  generate_replication_client_identity = var.replication_client_certificate_secret_arn == null
  replication_client_certificate_secret_arn = local.generate_replication_client_identity ? (
    aws_secretsmanager_secret.replication_client_cert[0].arn
  ) : var.replication_client_certificate_secret_arn
  replication_client_private_key_secret_arn = local.generate_replication_client_identity ? (
    aws_secretsmanager_secret.replication_client_key[0].arn
  ) : var.replication_client_private_key_secret_arn
  replication_client_ca_certificate_pem = local.generate_replication_client_identity ? (
    tls_self_signed_cert.replication_client_ca[0].cert_pem
  ) : var.replication_client_ca_certificate_pem
  replication_client_material_revision = local.generate_replication_client_identity ? sha256(join("", [
    tls_locally_signed_cert.replication_client[0].cert_pem,
    tls_self_signed_cert.replication_client_ca[0].cert_pem,
  ])) : var.replication_client_material_version

}

# =============================================================================
# HMAC Key (generated when not provided)
# =============================================================================

resource "random_id" "hmac" {
  count       = var.hmac_key == null ? 1 : 0
  byte_length = 32 # 32 bytes = 64 hex characters
}

# =============================================================================
# Public server TLS is generated at boot with the instance IP as its SAN.
# The Terraform state therefore holds no unused edge-server private key.
# =============================================================================

# =============================================================================
# Replication mTLS — one revocable client identity per edge pod
# =============================================================================

resource "tls_private_key" "replication_client_ca" {
  count       = local.generate_replication_client_identity ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "replication_client_ca" {
  count                 = local.generate_replication_client_identity ? 1 : 0
  private_key_pem       = tls_private_key.replication_client_ca[0].private_key_pem
  validity_period_hours = 8760
  early_renewal_hours   = 720
  is_ca_certificate     = true

  subject { common_name = "${var.name_prefix} replication client CA" }

  allowed_uses = ["digital_signature", "cert_signing", "crl_signing"]
}

resource "tls_private_key" "replication_client" {
  count       = local.generate_replication_client_identity ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "replication_client" {
  count           = local.generate_replication_client_identity ? 1 : 0
  private_key_pem = tls_private_key.replication_client[0].private_key_pem

  subject { common_name = "${var.name_prefix} replication client" }
}

resource "tls_locally_signed_cert" "replication_client" {
  count              = local.generate_replication_client_identity ? 1 : 0
  cert_request_pem   = tls_cert_request.replication_client[0].cert_request_pem
  ca_private_key_pem = tls_private_key.replication_client_ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.replication_client_ca[0].cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 720

  allowed_uses = ["digital_signature", "key_encipherment", "client_auth"]
}

resource "aws_secretsmanager_secret" "replication_client_cert" {
  #checkov:skip=CKV_AWS_149: Uses the account's managed Secrets Manager key by default
  #checkov:skip=CKV2_AWS_57: Certificate rotation requires coordinated write-tier trust rotation
  count       = local.generate_replication_client_identity ? 1 : 0
  name_prefix = "${var.name_prefix}-replication-client-cert-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "replication_client_cert" {
  count     = local.generate_replication_client_identity ? 1 : 0
  secret_id = aws_secretsmanager_secret.replication_client_cert[0].id
  secret_string = join("\n", [
    tls_locally_signed_cert.replication_client[0].cert_pem,
    tls_self_signed_cert.replication_client_ca[0].cert_pem,
  ])
}

resource "aws_secretsmanager_secret" "replication_client_key" {
  #checkov:skip=CKV_AWS_149: Uses the account's managed Secrets Manager key by default
  #checkov:skip=CKV2_AWS_57: Client-key rotation requires coordinated write-tier trust rotation
  count       = local.generate_replication_client_identity ? 1 : 0
  name_prefix = "${var.name_prefix}-replication-client-key-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "replication_client_key" {
  count         = local.generate_replication_client_identity ? 1 : 0
  secret_id     = aws_secretsmanager_secret.replication_client_key[0].id
  secret_string = tls_private_key.replication_client[0].private_key_pem
}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "edge" {
  name_prefix = "${var.name_prefix}-edge-"
  description = "Edge pod - QUIC/gRPC ingress, write tier egress"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-edge" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "client_quic_grpc_tcp" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.edge.id
  description       = "Client gRPC TCP (${each.value})"
  cidr_ipv4         = each.value
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "client_quic_grpc_udp" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.edge.id
  description       = "Client QUIC UDP (${each.value})"
  cidr_ipv4         = each.value
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "client_http" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.edge.id
  description       = "Client HTTP (${each.value})"
  cidr_ipv4         = each.value
  from_port         = 41339
  to_port           = 41339
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.edge.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow the edge pod to reach only the write tier ports it uses.
resource "aws_vpc_security_group_ingress_rule" "write_tier_from_edge" {
  count                        = var.server_security_group_id != null ? 1 : 0
  security_group_id            = var.server_security_group_id
  description                  = "Public gRPC from edge pod"
  referenced_security_group_id = aws_security_group.edge.id
  from_port                    = 41337
  to_port                      = 41337
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "write_tier_from_edge_quic" {
  count                        = var.server_security_group_id != null ? 1 : 0
  security_group_id            = var.server_security_group_id
  description                  = "Public QUIC from edge pod"
  referenced_security_group_id = aws_security_group.edge.id
  from_port                    = 41337
  to_port                      = 41337
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "write_tier_from_edge_udp" {
  count                        = var.server_security_group_id != null ? 1 : 0
  security_group_id            = var.server_security_group_id
  description                  = "mTLS replication QUIC from edge pod"
  referenced_security_group_id = aws_security_group.edge.id
  from_port                    = 41340
  to_port                      = 41340
  ip_protocol                  = "udp"
}

# =============================================================================
# IAM Role + Instance Profile (ECR pull + SSM)
# =============================================================================

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "edge" {
  name_prefix        = "${var.name_prefix}-edge-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.edge.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "ecr" {
  #checkov:skip=CKV_AWS_356: ecr:GetAuthorizationToken requires resource "*" — AWS API limitation, cannot be scoped to specific repos
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecr" {
  name   = "ecr-pull"
  role   = aws_iam_role.edge.id
  policy = data.aws_iam_policy_document.ecr.json
}

data "aws_iam_policy_document" "replication_client_secrets" {
  statement {
    sid     = "ReadReplicationClientIdentity"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      local.replication_client_certificate_secret_arn,
      local.replication_client_private_key_secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "replication_client_secrets" {
  name_prefix = "replication-client-secrets-"
  role        = aws_iam_role.edge.id
  policy      = data.aws_iam_policy_document.replication_client_secrets.json
}

resource "aws_iam_instance_profile" "edge" {
  name_prefix = "${var.name_prefix}-edge-"
  role        = aws_iam_role.edge.name
  tags        = var.tags
}

# =============================================================================
# EC2 Instance
# =============================================================================

resource "aws_instance" "edge" {
  #checkov:skip=CKV_AWS_126: Detailed monitoring optional — adds cost, basic monitoring sufficient for cache nodes
  #checkov:skip=CKV_AWS_135: EBS optimization not applicable — NVMe instance store is the primary storage, not EBS
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.edge.name
  vpc_security_group_ids = [aws_security_group.edge.id]

  user_data_base64 = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    ecr_region                                 = local.ecr_region
    ecr_registry                               = local.ecr_registry
    ca_cert_pem_base64                         = base64encode(var.ca_certificate_pem)
    replication_client_certificate_secret_arn  = local.replication_client_certificate_secret_arn
    replication_client_private_key_secret_arn  = local.replication_client_private_key_secret_arn
    replication_client_material_revision       = local.replication_client_material_revision
    container_image                            = var.container_image
    write_tier_dns                             = var.write_tier_dns
    hmac_key                                   = local.hmac_key
    replication_expected_rtt_ms                = var.replication_expected_rtt_ms != null ? tostring(var.replication_expected_rtt_ms) : ""
    replication_max_bandwidth_bytes_per_second = var.replication_max_bandwidth_bytes_per_second != null ? tostring(var.replication_max_bandwidth_bytes_per_second) : ""
  }))
  # cloud-init runs this bootstrap once. Replacing on change prevents a running pod from keeping
  # obsolete replication credentials or an insecure transport configuration.
  user_data_replace_on_change = true

  # Ensure generated values and permission propagation precede cloud-init's fail-closed fetch.
  depends_on = [
    aws_secretsmanager_secret_version.replication_client_cert,
    aws_secretsmanager_secret_version.replication_client_key,
    aws_iam_role_policy.replication_client_secrets,
  ]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-edge-pod" })
}
