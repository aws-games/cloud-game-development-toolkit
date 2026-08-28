#!/usr/bin/env bash
# scripts/test-connectivity.sh — Verify client connectivity to a Lore deployment.
# Requires: bash 4+, aws CLI, lore binary
# Platforms: Linux, macOS, WSL2
# Usage: ./scripts/test-connectivity.sh <lore-binary> [host:port]
set -euo pipefail

LORE="${1:?Usage: $0 <lore-binary> [host:port]}"
TARGET="${2:-127.0.0.1:41337}"
HOST="${TARGET%%:*}"
PORT="${TARGET##*:}"

echo "=== Lore Connectivity Test ==="
echo "  Target: $TARGET"
echo "  Binary: $LORE"
echo ""

# 1. Binary check
echo "--- Binary ---"
if "$LORE" --version 2>/dev/null; then
  echo "  ✓ Binary OK"
else
  echo "  ✗ Binary not found or not executable" >&2
  exit 1
fi
echo ""

# 2. TCP connectivity (gRPC)
echo "--- TCP :$PORT (gRPC) ---"
if timeout 3 bash -c "echo >/dev/tcp/$HOST/$PORT" 2>/dev/null; then
  echo "  ✓ TCP OPEN"
else
  echo "  ✗ TCP CLOSED — check tunnel, firewall, or security group"
  echo "    Hint: If using SSM tunnel, run scripts/ssm-tunnel.sh first"
fi
echo ""

# 3. gRPC operation
echo "--- gRPC list repos ---"
if OUTPUT=$(timeout 10 "$LORE" repository list "grpc://$TARGET/" 2>&1); then
  REPO_COUNT=$(echo "$OUTPUT" | wc -l)
  echo "  ✓ gRPC works ($REPO_COUNT repos found)"
else
  RC=$?
  if [ $RC -eq 124 ]; then
    echo "  ✗ gRPC TIMEOUT (10s) — server may be unresponsive or tunnel stale"
  else
    # Extract the actionable error (first meaningful phrase after "Error")
    SHORT_ERR=$(echo "$OUTPUT" | grep -o 'Connection refused\|tls handshake\|connection reset\|permission denied\|authorization' | head -1)
    echo "  ✗ gRPC failed: ${SHORT_ERR:-unknown error}"
    echo "    Full error: $(echo "$OUTPUT" | head -1 | cut -c1-120)"
  fi
fi
echo ""

# 4. TLS bundle check
echo "--- TLS bundle ---"
if [[ -n "${SSL_CERT_FILE:-}" ]]; then
  if [[ -f "$SSL_CERT_FILE" ]]; then
    LINES=$(wc -l < "$SSL_CERT_FILE")
    echo "  ✓ SSL_CERT_FILE=$SSL_CERT_FILE ($LINES lines)"
  else
    echo "  ✗ SSL_CERT_FILE set but file not found: $SSL_CERT_FILE"
  fi
else
  echo "  ⚠ SSL_CERT_FILE not set — lores:// will fail TLS validation"
  echo "    Hint: Run scripts/build-ca-bundle.sh to create the bundle"
fi
echo ""

# 5. QUIC (only works with direct UDP connectivity, not over SSM tunnel)
echo "--- QUIC (lore://) ---"
if [[ "$HOST" == "127.0.0.1" || "$HOST" == "localhost" ]]; then
  echo "  ⚠ Skipped — QUIC (UDP) cannot traverse SSM port forward (TCP-only)"
  echo "    To test QUIC, run from within the VPC via SSM send-command"
else
  if OUTPUT=$(timeout 10 "$LORE" repository list "lore://$TARGET/" 2>&1); then
    echo "  ✓ QUIC works"
  else
    RC=$?
    if [ $RC -eq 124 ]; then
      echo "  ✗ QUIC TIMEOUT (10s) — UDP may be blocked or server unresponsive"
    else
      echo "  ✗ QUIC failed: $(echo "$OUTPUT" | head -1)"
    fi
  fi
fi
echo ""

echo "=== Summary ==="
echo "  gRPC (grpc://$TARGET/):  use for dev/test over SSM tunnel"
echo "  QUIC (lore://$TARGET/):  requires direct UDP connectivity"
echo "  QUIC+TLS (lores://):     requires UDP + SSL_CERT_FILE bundle"
