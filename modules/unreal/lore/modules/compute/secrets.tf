# =============================================================================
# TLS certificates — private CA plus separate server and replication-client identities
# =============================================================================

locals {
  generate_tls_material      = var.tls_certificate_secret_arn == null
  replication_client_enabled = var.durable_store_mode == "replicated" || length(var.replication_peers) > 0
}

# --- CA (trust anchor) ---
resource "tls_private_key" "ca" {
  count       = local.generate_tls_material ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  count                 = local.generate_tls_material ? 1 : 0
  private_key_pem       = tls_private_key.ca[0].private_key_pem
  validity_period_hours = 8760
  early_renewal_hours   = 720
  is_ca_certificate     = true

  subject { common_name = "Lore Internal CA" }

  allowed_uses = ["digital_signature", "cert_signing", "crl_signing"]
}

# --- Server identity (serverAuth only) ---
resource "tls_private_key" "server" {
  count       = local.generate_tls_material ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "server" {
  count           = local.generate_tls_material ? 1 : 0
  private_key_pem = tls_private_key.server[0].private_key_pem

  subject { common_name = "loreserver.internal" }

  dns_names = concat(
    ["loreserver.internal", "localhost"],
    compact([var.write_tier_dns_name]),
    var.tls_san_dns_names
  )
  ip_addresses = ["127.0.0.1"]
}

resource "tls_locally_signed_cert" "server" {
  count              = local.generate_tls_material ? 1 : 0
  cert_request_pem   = tls_cert_request.server[0].cert_request_pem
  ca_private_key_pem = tls_private_key.ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca[0].cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 720

  allowed_uses = ["digital_signature", "key_encipherment", "server_auth"]
}

resource "aws_secretsmanager_secret" "tls_cert" {
  #checkov:skip=CKV_AWS_149: Rotation not applicable — TLS cert is Terraform-generated and replaced on apply
  #checkov:skip=CKV2_AWS_57: Rotation not applicable — TLS cert is Terraform-generated and replaced on apply
  count       = local.generate_tls_material ? 1 : 0
  name_prefix = "${var.name_prefix}-tls-cert-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "tls_cert" {
  count         = local.generate_tls_material ? 1 : 0
  secret_id     = aws_secretsmanager_secret.tls_cert[0].id
  secret_string = tls_locally_signed_cert.server[0].cert_pem
}

resource "aws_secretsmanager_secret" "tls_ca" {
  #checkov:skip=CKV_AWS_149: Rotation not applicable — CA cert is Terraform-generated trust anchor, replaced on apply
  #checkov:skip=CKV2_AWS_57: Rotation not applicable — CA cert is Terraform-generated trust anchor, replaced on apply
  count       = local.generate_tls_material ? 1 : 0
  name_prefix = "${var.name_prefix}-tls-ca-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "tls_ca" {
  count         = local.generate_tls_material ? 1 : 0
  secret_id     = aws_secretsmanager_secret.tls_ca[0].id
  secret_string = tls_self_signed_cert.ca[0].cert_pem
}

resource "aws_secretsmanager_secret" "tls_key" {
  #checkov:skip=CKV_AWS_149: Rotation not applicable — private key is Terraform-generated and replaced on apply
  #checkov:skip=CKV2_AWS_57: Rotation not applicable — private key is Terraform-generated and replaced on apply
  count       = local.generate_tls_material ? 1 : 0
  name_prefix = "${var.name_prefix}-tls-key-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "tls_key" {
  count         = local.generate_tls_material ? 1 : 0
  secret_id     = aws_secretsmanager_secret.tls_key[0].id
  secret_string = tls_private_key.server[0].private_key_pem
}

# --- Replication client identity (clientAuth only) ---
# One identity is shared by this tier's tasks and any edge pods that receive the two secret ARNs.
# It is separate from the server key so a replication client cannot impersonate a server.
resource "tls_private_key" "replication_client" {
  count       = local.generate_tls_material && local.replication_client_enabled ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "replication_client" {
  count           = local.generate_tls_material && local.replication_client_enabled ? 1 : 0
  private_key_pem = tls_private_key.replication_client[0].private_key_pem

  subject { common_name = "${var.name_prefix} replication client" }
}

resource "tls_locally_signed_cert" "replication_client" {
  count              = local.generate_tls_material && local.replication_client_enabled ? 1 : 0
  cert_request_pem   = tls_cert_request.replication_client[0].cert_request_pem
  ca_private_key_pem = tls_private_key.ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca[0].cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 720

  allowed_uses = ["digital_signature", "key_encipherment", "client_auth"]
}

resource "aws_secretsmanager_secret" "tls_client_cert" {
  #checkov:skip=CKV_AWS_149: Rotation not applicable — TLS cert is Terraform-generated and replaced on apply
  #checkov:skip=CKV2_AWS_57: Rotation not applicable — TLS cert is Terraform-generated and replaced on apply
  count       = local.generate_tls_material && local.replication_client_enabled ? 1 : 0
  name_prefix = "${var.name_prefix}-tls-client-cert-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "tls_client_cert" {
  count         = local.generate_tls_material && local.replication_client_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.tls_client_cert[0].id
  secret_string = tls_locally_signed_cert.replication_client[0].cert_pem
}

resource "aws_secretsmanager_secret" "tls_client_key" {
  #checkov:skip=CKV_AWS_149: Rotation not applicable — private key is Terraform-generated and replaced on apply
  #checkov:skip=CKV2_AWS_57: Rotation not applicable — private key is Terraform-generated and replaced on apply
  count       = local.generate_tls_material && local.replication_client_enabled ? 1 : 0
  name_prefix = "${var.name_prefix}-tls-client-key-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "tls_client_key" {
  count         = local.generate_tls_material && local.replication_client_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.tls_client_key[0].id
  secret_string = tls_private_key.replication_client[0].private_key_pem
}

# =============================================================================
# HMAC Key — replaces hardcoded hex value
# =============================================================================

resource "random_bytes" "hmac_key" {
  count  = var.hmac_key_secret_arn == null ? 1 : 0
  length = 32
}

resource "aws_secretsmanager_secret" "hmac_key" {
  #checkov:skip=CKV_AWS_149: Rotation not applicable — HMAC key is Terraform-generated random bytes, replaced on apply
  #checkov:skip=CKV2_AWS_57: Rotation not applicable — HMAC key is Terraform-generated random bytes, replaced on apply
  count       = var.hmac_key_secret_arn == null ? 1 : 0
  name_prefix = "${var.name_prefix}-hmac-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "hmac_key" {
  count         = var.hmac_key_secret_arn == null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.hmac_key[0].id
  secret_string = random_bytes.hmac_key[0].hex
}

# =============================================================================
# Locals — resolve final ARNs (user-provided or generated)
# =============================================================================

locals {
  tls_cert_secret_arn = var.tls_certificate_secret_arn != null ? var.tls_certificate_secret_arn : aws_secretsmanager_secret.tls_cert[0].arn
  tls_ca_secret_arn   = var.tls_ca_certificate_secret_arn != null ? var.tls_ca_certificate_secret_arn : aws_secretsmanager_secret.tls_ca[0].arn
  tls_key_secret_arn  = var.tls_private_key_secret_arn != null ? var.tls_private_key_secret_arn : aws_secretsmanager_secret.tls_key[0].arn
  tls_client_cert_secret_arn = local.replication_client_enabled ? (
    var.tls_client_certificate_secret_arn != null ? var.tls_client_certificate_secret_arn : try(aws_secretsmanager_secret.tls_client_cert[0].arn, null)
  ) : null
  tls_client_key_secret_arn = local.replication_client_enabled ? (
    var.tls_client_private_key_secret_arn != null ? var.tls_client_private_key_secret_arn : try(aws_secretsmanager_secret.tls_client_key[0].arn, null)
  ) : null
  hmac_key_secret_arn = coalesce(var.hmac_key_secret_arn, try(aws_secretsmanager_secret.hmac_key[0].arn, ""))
  tls_material_revision = local.generate_tls_material ? sha256(join("", compact([
    tls_locally_signed_cert.server[0].cert_pem,
    tls_self_signed_cert.ca[0].cert_pem,
    try(tls_locally_signed_cert.replication_client[0].cert_pem, null),
  ]))) : var.tls_material_version
}
