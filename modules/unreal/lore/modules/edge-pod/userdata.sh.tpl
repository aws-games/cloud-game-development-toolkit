#!/bin/bash
# Replication identity revision: ${replication_client_material_revision}
set -euo pipefail

# --- NVMe setup ---
NVME_DEV=$(lsblk -dpno NAME,MODEL | awk '/Instance Storage/ {print $1; exit}')
mkdir -p /srv/urc
if [[ -n "$NVME_DEV" ]]; then
  mkfs.xfs -f "$NVME_DEV"
  mount "$NVME_DEV" /srv/urc
fi
chown 65534:65534 /srv/urc

# --- Docker + ECR login (retry — NAT gateway may not be ready on first boot) ---
dnf clean all
dnf install -y docker
systemctl enable --now docker
ECR_OK=0
for i in $(seq 1 12); do
  aws ecr get-login-password --region "${ecr_region}" | docker login --username AWS --password-stdin "${ecr_registry}" && { ECR_OK=1; break; }
  echo "ECR login attempt $i failed, retrying in 10s..."
  sleep 10
done
[[ $ECR_OK -eq 1 ]] || { echo "FATAL: ECR login failed after 12 attempts"; exit 1; }

# --- Write-tier trust and mTLS client identity ---
umask 077
mkdir -p /opt/edge/certs
printf '%s' "${ca_cert_pem_base64}" | base64 -d > /opt/edge/certs/write-tier-ca.pem

fetch_secret() {
  secret_arn="$1"
  destination="$2"
  secret_region=$(printf '%s' "$secret_arn" | cut -d: -f4)
  for attempt in $(seq 1 12); do
    if aws secretsmanager get-secret-value \
      --region "$secret_region" \
      --secret-id "$secret_arn" \
      --query SecretString \
      --output text \
      --no-cli-pager > "$destination.tmp" && [[ -s "$destination.tmp" ]]; then
      mv "$destination.tmp" "$destination"
      return 0
    fi
    rm -f "$destination.tmp"
    echo "Replication identity retrieval attempt $attempt failed, retrying in 10s..."
    sleep 10
  done
  return 1
}

fetch_secret "${replication_client_certificate_secret_arn}" /opt/edge/certs/replication-client.crt || {
  echo "FATAL: Could not retrieve replication client certificate"
  exit 1
}
fetch_secret "${replication_client_private_key_secret_arn}" /opt/edge/certs/replication-client.key || {
  echo "FATAL: Could not retrieve replication client private key"
  exit 1
}
chmod 600 /opt/edge/certs/replication-client.key
chmod 644 /opt/edge/certs/replication-client.crt /opt/edge/certs/write-tier-ca.pem

# --- Self-signed cert with IP SAN (CA:FALSE) ---
INSTANCE_IP=$(TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60") && \
  curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
[[ -n "$INSTANCE_IP" ]] || { echo "FATAL: Could not retrieve instance IP from IMDS"; exit 1; }

openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout /opt/edge/certs/server.key -out /opt/edge/certs/server.crt \
  -days 365 -nodes -subj "/CN=edge-pod" \
  -addext "subjectAltName=IP:$INSTANCE_IP" \
  -addext "basicConstraints=critical,CA:FALSE"

cat /opt/edge/certs/server.crt > /opt/edge/certs/fullchain.crt
chown 65534:65534 /opt/edge/certs/server.key /opt/edge/certs/replication-client.key
chmod 600 /opt/edge/certs/server.key /opt/edge/certs/replication-client.key
chmod 644 /opt/edge/certs/server.crt /opt/edge/certs/fullchain.crt /opt/edge/certs/replication-client.crt /opt/edge/certs/write-tier-ca.pem
chmod 755 /opt/edge/certs

# --- Combined CA bundle ---
cat /etc/pki/tls/certs/ca-bundle.crt /opt/edge/certs/write-tier-ca.pem > /opt/edge/certs/combined-ca.pem
chmod 644 /opt/edge/certs/combined-ca.pem

# --- Optional replicated-client tuning ---
REPLICATION_ENV=()
if [[ -n "${replication_expected_rtt_ms}" ]]; then
  REPLICATION_ENV+=(-e "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__EXPECTED_RTT_MS=${replication_expected_rtt_ms}")
fi
if [[ -n "${replication_max_bandwidth_bytes_per_second}" ]]; then
  REPLICATION_ENV+=(-e "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__MAX_BANDWIDTH_BYTES_PER_SECOND=${replication_max_bandwidth_bytes_per_second}")
fi

# --- Run edge pod ---
docker run -d --name edge-pod \
  --restart unless-stopped \
  --network host \
  --user 65534:65534 \
  -v /srv/urc:/srv/urc \
  -v /opt/edge/certs:/certs:ro \
  -e LORE_ENV=docker \
  -e SSL_CERT_FILE=/certs/combined-ca.pem \
  -e "LORE__SERVER__HTTP__PRESIGNED_URL_HMAC_KEY=${hmac_key}" \
  -e LORE__SERVER__QUIC__CERTIFICATE__CERT_FILE=/certs/fullchain.crt \
  -e LORE__SERVER__QUIC__CERTIFICATE__PKEY_FILE=/certs/server.key \
  -e LORE__SERVER__GRPC__CERTIFICATE__CERT_FILE=/certs/fullchain.crt \
  -e LORE__SERVER__GRPC__CERTIFICATE__PKEY_FILE=/certs/server.key \
  -e LORE__SERVER__GRPC__VERIFY_CLIENT_CERTS=false \
  -e LORE__IMMUTABLE_STORE__MODE=composite \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__LOCAL__MODE=local \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__LOCAL__LOCAL__PATH=/srv/urc \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__LOCAL__LOCAL__MAX_SIZE=800000000000 \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__LOCAL__LOCAL__FLUSH_DELAY_SECONDS=10 \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__MODE=replicated \
  -e "LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__REMOTE_URL=lores://${write_tier_dns}:41340" \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__CERTS__CERT_FILE=/certs/replication-client.crt \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__CERTS__PKEY_FILE=/certs/replication-client.key \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__CERTS__CERT_CHAIN=/certs/write-tier-ca.pem \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__REGENERATE_RETRY__INITIAL_BACKOFF_MS=100 \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__REGENERATE_RETRY__MAX_BACKOFF_MS=1000 \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__REGENERATE_RETRY__MAX_ATTEMPTS=10 \
  -e LORE__IMMUTABLE_STORE__COMPOSITE__DURABLE__REPLICATED__PERIODIC_CLIENT_REFRESH_SECS=180 \
  -e LORE__MUTABLE_STORE__MODE=remote \
  -e "LORE__MUTABLE_STORE__REMOTE__REMOTE_URL=lores://${write_tier_dns}:41337" \
  -e LORE__LOCK_STORE__MODE=local \
  "$${REPLICATION_ENV[@]}" \
  "${container_image}"
