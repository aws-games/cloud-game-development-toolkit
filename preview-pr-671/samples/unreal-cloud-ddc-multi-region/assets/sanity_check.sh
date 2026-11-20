#!/usr/bin/env bash
#
# sanity_check.sh
#
# Writes a test blob to Unreal Cloud DDC, reads it back, and checks that the
# bytes match. Exits non-zero on any failure.
#
# Usage (from the sample directory, after terraform apply):
#   assets/sanity_check.sh [ddc-host]
#
#   ddc-host  Host to test. Defaults to the unreal_ddc_url Terraform output.
#             Pass a regional name (<name_prefix>-<region>.<zone>) to test one
#             region.
#
# Environment (optional):
#   DDC_SCHEME  https or http (default https)
#
# The bearer token is read from Secrets Manager into a private temp file and
# passed to curl with -H @file, so it never appears in logs or process arguments.
#
set -euo pipefail

cd "$(dirname "$0")/.."

err() { echo "error: $*" >&2; exit 1; }
for bin in terraform aws curl; do
  command -v "$bin" >/dev/null 2>&1 || err "$bin not found on PATH"
done

scheme="${DDC_SCHEME:-https}"
if [[ -n "${1:-}" ]]; then
  host="$1"
else
  host="$(terraform output -raw unreal_ddc_url 2>/dev/null)" || err "no unreal_ddc_url output; run terraform apply first"
fi
host="${host%.}"
[[ -n "$host" ]] || err "no DDC host"
secret_arn="$(terraform output -raw unreal_cloud_ddc_bearer_token_arn 2>/dev/null)" \
  || err "no unreal_cloud_ddc_bearer_token_arn output; run terraform apply first"
[[ "$secret_arn" == arn:* ]] || err "unexpected secret ARN: ${secret_arn}"
secret_region="$(cut -d: -f4 <<<"$secret_arn")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
chmod 700 "$work"

umask 077
token="$(aws secretsmanager get-secret-value --region "$secret_region" --secret-id "$secret_arn" \
  --query SecretString --output text)" || err "could not read the bearer token secret"
[[ -n "$token" ]] || err "bearer token secret is empty"
printf 'Authorization: ServiceAccount %s\n' "$token" > "$work/auth"
unset token

base="${scheme}://${host}/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa"
payload="test"
# IoHash (BLAKE3, truncated) of the 4-byte payload "test".
iohash="4878CA0425C739FA427F7EDA20FE845F6B2E46BA"

echo "PUT ${base}"
put_code="$(curl --silent --show-error --fail-with-body \
  -o "$work/put.body" -w '%{http_code}' \
  -X PUT --data-binary "$payload" \
  -H 'content-type: application/octet-stream' \
  -H "X-Jupiter-IoHash: ${iohash}" \
  -H @"$work/auth" \
  "$base")" || { cat "$work/put.body" >&2 2>/dev/null; err "PUT failed (HTTP ${put_code:-none})"; }
[[ "$put_code" == "200" ]] || err "PUT returned HTTP ${put_code}, expected 200"

echo "GET ${base}.raw"
get_code="$(curl --silent --show-error --fail-with-body \
  -o "$work/get.body" -w '%{http_code}' \
  -H @"$work/auth" \
  "${base}.raw")" || { cat "$work/get.body" >&2 2>/dev/null; err "GET failed (HTTP ${get_code:-none})"; }
[[ "$get_code" == "200" ]] || err "GET returned HTTP ${get_code}, expected 200"

printf '%s' "$payload" > "$work/sent"
cmp -s "$work/sent" "$work/get.body" || err "fetched bytes do not match what was sent"

echo "OK: ${host} stored and returned the test blob"
