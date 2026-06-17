# =============================================================================
# TLS Certificate — CA + server cert fallback when no external cert ARN provided
# =============================================================================

# --- CA (trust anchor) ---
resource "tls_private_key" "ca" {
  count       = var.tls_certificate_secret_arn == null ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  count                 = var.tls_certificate_secret_arn == null ? 1 : 0
  private_key_pem       = tls_private_key.ca[0].private_key_pem
  validity_period_hours = 8760
  is_ca_certificate     = true

  subject { common_name = "Lore Internal CA" }

  allowed_uses = ["digital_signature", "cert_signing", "crl_signing"]
}

# --- Server cert (signed by CA) ---
resource "tls_private_key" "server" {
  count       = var.tls_private_key_secret_arn == null ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "server" {
  count           = var.tls_certificate_secret_arn == null ? 1 : 0
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
  count              = var.tls_certificate_secret_arn == null ? 1 : 0
  cert_request_pem   = tls_cert_request.server[0].cert_request_pem
  ca_private_key_pem = tls_private_key.ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca[0].cert_pem

  validity_period_hours = 8760

  allowed_uses = ["digital_signature", "key_encipherment", "server_auth"]
}

resource "aws_secretsmanager_secret" "tls_cert" {
  count       = var.tls_certificate_secret_arn == null ? 1 : 0
  name_prefix = "${var.name_prefix}-tls-cert-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "tls_cert" {
  count         = var.tls_certificate_secret_arn == null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.tls_cert[0].id
  secret_string = tls_locally_signed_cert.server[0].cert_pem
}

resource "aws_secretsmanager_secret" "tls_ca" {
  count       = var.tls_certificate_secret_arn == null ? 1 : 0
  name_prefix = "${var.name_prefix}-tls-ca-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "tls_ca" {
  count         = var.tls_certificate_secret_arn == null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.tls_ca[0].id
  secret_string = tls_self_signed_cert.ca[0].cert_pem
}

resource "aws_secretsmanager_secret" "tls_key" {
  count       = var.tls_private_key_secret_arn == null ? 1 : 0
  name_prefix = "${var.name_prefix}-tls-key-"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "tls_key" {
  count         = var.tls_private_key_secret_arn == null ? 1 : 0
  secret_id     = aws_secretsmanager_secret.tls_key[0].id
  secret_string = tls_private_key.server[0].private_key_pem
}

# =============================================================================
# HMAC Key — replaces hardcoded hex value
# =============================================================================

resource "random_bytes" "hmac_key" {
  count  = var.hmac_key_secret_arn == null ? 1 : 0
  length = 32
}

resource "aws_secretsmanager_secret" "hmac_key" {
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
  tls_cert_secret_arn = coalesce(var.tls_certificate_secret_arn, try(aws_secretsmanager_secret.tls_cert[0].arn, ""))
  tls_ca_secret_arn   = try(aws_secretsmanager_secret.tls_ca[0].arn, "")
  tls_key_secret_arn  = coalesce(var.tls_private_key_secret_arn, try(aws_secretsmanager_secret.tls_key[0].arn, ""))
  hmac_key_secret_arn = coalesce(var.hmac_key_secret_arn, try(aws_secretsmanager_secret.hmac_key[0].arn, ""))
}
