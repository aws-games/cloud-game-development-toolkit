#!/usr/bin/env bash
# scripts/build-ca-bundle.sh — Export CA cert from Terraform and build combined trust bundle.
# Usage: ./scripts/build-ca-bundle.sh [terraform-dir] [output-path]
#
# Sets SSL_CERT_FILE for lores:// (QUIC+TLS) connections.
# The bundle REPLACES the system trust store (rustls-native-certs behavior),
# Requires: bash 4+, terraform CLI
# Platforms: Linux, macOS, WSL2
# so it must include both system certs AND the Lore CA.
set -euo pipefail

TF_DIR="${1:-$(dirname "$0")/../examples/minimal}"
OUTPUT="${2:-/tmp/lore-combined-ca.pem}"

echo "=== Building CA bundle ==="
echo "  Terraform dir: $TF_DIR"
echo "  Output:        $OUTPUT"
echo ""

# Extract CA cert from Terraform state
cd "$TF_DIR"
CA_PEM=$(terraform state show 'module.lore.module.compute.tls_self_signed_cert.ca[0]' 2>/dev/null \
  | sed -n '/cert_pem.*<<-EOT/,/EOT/{ /cert_pem/d; /EOT/d; s/^[[:space:]]*//; p }')

if [[ -z "$CA_PEM" ]]; then
  # Fallback: try terraform output (works regardless of resource naming)
  CA_PEM=$(terraform output -raw ca_certificate_pem 2>/dev/null || true)
fi

if [[ -z "$CA_PEM" ]]; then
  echo "ERROR: Could not extract CA cert from Terraform state." >&2
  echo "  Is infrastructure deployed? Run 'terraform apply' first." >&2
  exit 1
fi

# Find system CA bundle
if [[ -f /etc/pki/tls/certs/ca-bundle.crt ]]; then
  SYSTEM_CA=/etc/pki/tls/certs/ca-bundle.crt
elif [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
  SYSTEM_CA=/etc/ssl/certs/ca-certificates.crt
else
  echo "ERROR: System CA bundle not found" >&2
  exit 1
fi

# Build combined bundle
cat "$SYSTEM_CA" > "$OUTPUT"
echo "$CA_PEM" >> "$OUTPUT"

LINES=$(wc -l < "$OUTPUT")
echo "  ✓ Combined bundle: $OUTPUT ($LINES lines)"
echo ""
echo "To use:"
echo "  export SSL_CERT_FILE=$OUTPUT"
echo ""
echo "Then connect with lores:// scheme:"
echo "  lore repository list lores://<nlb-dns>:41337/"
