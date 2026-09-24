#!/usr/bin/env bash
#
# eks-api-tunnel.sh
#
# Opens an SSM port-forward from a local port to the EKS cluster's PRIVATE API
# endpoint, tunnelled through an in-VPC SSM-managed EC2 instance. Use this when
# your host cannot reach the cluster's PUBLIC endpoint (corporate NAT/VPN/CI
# egress filtering) but the cluster has endpoint_private_access = true.
#
# Terraform then points the kubernetes/helm providers at 127.0.0.1:<local-port>
# (set var.eks_api_local_port to that port) while TLS is still validated against
# the real cluster hostname (tls_server_name), so CA validation stays intact.
# There is no insecure=true and no 0.0.0.0/0 exposure.
#
# Nothing is hardcoded: the cluster name, private endpoint hostname, and the
# SSM target instance are all discovered at runtime from AWS APIs. You only
# provide the local port (and optionally the cluster name / region / instance
# if auto-discovery is ambiguous in your account).
#
# Usage:
#   scripts/eks-api-tunnel.sh [local-port] [cluster-name]
#
#   local-port    Local port to bind (default 9443). Must match
#                 var.eks_api_local_port (1024-65535).
#   cluster-name  Optional; auto-discovered when omitted (see below).
#
#   scripts/eks-api-tunnel.sh --help    Show this help.
#
# Environment overrides (all optional):
#   AWS_REGION / AWS_DEFAULT_REGION  Region to operate in (falls back to CLI config)
#   EKS_CLUSTER_NAME                 Cluster name (else auto-discovered / positional)
#   SSM_INSTANCE_ID                  SSM target instance (else auto-discovered in cluster VPC)
#
# Requirements: awscli v2, session-manager-plugin, jq. The target instance must
# be registered with SSM (managed instance) and have network access to the EKS
# private endpoint (443).
#
set -euo pipefail

err() { echo "error: $*" >&2; exit 1; }

usage() {
  # Print the leading comment block (between the shebang and `set -euo pipefail`).
  sed -n '2,/^set -euo pipefail/{/^set -euo pipefail/d;s/^#\{0,1\} \{0,1\}//;p}' "$0"
}

# --- Help --------------------------------------------------------------------
for arg in "$@"; do
  case "${arg}" in
    -h|--help|help) usage; exit 0 ;;
  esac
done

# --- Local port (positional arg 1, default 9443) -----------------------------
# The value must match var.eks_api_local_port (1024-65535) that Terraform's
# kubernetes/helm providers point at (127.0.0.1:<local-port>).
LOCAL_PORT="${1:-${LOCAL_PORT:-9443}}"
[[ "${LOCAL_PORT}" =~ ^[0-9]+$ ]] || err "local-port must be numeric, got '${LOCAL_PORT}'"
if (( LOCAL_PORT < 1024 || LOCAL_PORT > 65535 )); then
  err "local-port must be between 1024 and 65535 (matches var.eks_api_local_port)"
fi

command -v aws >/dev/null 2>&1 || err "awscli not found on PATH"
command -v jq  >/dev/null 2>&1 || err "jq not found on PATH"
command -v session-manager-plugin >/dev/null 2>&1 \
  || err "session-manager-plugin not found on PATH (required for SSM port-forward)"

# --- Region (discovered from environment / CLI config, never hardcoded) -------
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || true)}}"
[[ -n "${REGION}" ]] || err "no region set (export AWS_REGION or configure the CLI)"

# --- Cluster name (positional arg > env > single-cluster auto-discovery) ------
CLUSTER_NAME="${2:-${EKS_CLUSTER_NAME:-}}"
if [[ -z "${CLUSTER_NAME}" ]]; then
  mapfile -t CLUSTERS < <(aws eks list-clusters --region "${REGION}" --query 'clusters[]' --output text | tr '\t' '\n')
  if (( ${#CLUSTERS[@]} == 0 )); then
    err "no EKS clusters found in ${REGION}"
  elif (( ${#CLUSTERS[@]} > 1 )); then
    err "multiple EKS clusters in ${REGION} (${CLUSTERS[*]}); pass the cluster name as arg 2 or set EKS_CLUSTER_NAME"
  fi
  CLUSTER_NAME="${CLUSTERS[0]}"
fi
echo "Cluster:  ${CLUSTER_NAME} (${REGION})"

# --- Cluster private endpoint + VPC (discovered at runtime) -------------------
CLUSTER_JSON="$(aws eks describe-cluster --region "${REGION}" --name "${CLUSTER_NAME}")"
ENDPOINT="$(jq -r '.cluster.endpoint' <<<"${CLUSTER_JSON}")"
[[ -n "${ENDPOINT}" && "${ENDPOINT}" != "null" ]] || err "could not resolve cluster endpoint"
ENDPOINT_HOST="${ENDPOINT#https://}"
VPC_ID="$(jq -r '.cluster.resourcesVpcConfig.vpcId' <<<"${CLUSTER_JSON}")"
[[ -n "${VPC_ID}" && "${VPC_ID}" != "null" ]] || err "could not resolve cluster VPC id"
echo "Endpoint: ${ENDPOINT_HOST}:443"
echo "VPC:      ${VPC_ID}"

# The private endpoint hostname resolves to private IPs inside the VPC. Resolve
# it on the remote instance side; here we resolve to a routable address for the
# port-forward target. AWS SSM port-forward-to-remote-host needs an IP or host
# the *instance* can reach, so we pass the hostname and let the instance resolve.

# --- SSM target instance (env override, else auto-discover in cluster VPC) ----
INSTANCE_ID="${SSM_INSTANCE_ID:-}"
if [[ -z "${INSTANCE_ID}" ]]; then
  # Intersect SSM-managed instances with instances in the cluster VPC.
  mapfile -t SSM_INSTANCES < <(aws ssm describe-instance-information \
    --region "${REGION}" \
    --query 'InstanceInformationList[?PingStatus==`Online`].InstanceId' \
    --output text | tr '\t' '\n' | sed '/^$/d')
  (( ${#SSM_INSTANCES[@]} > 0 )) || err "no Online SSM-managed instances found in ${REGION}"

  CANDIDATES=()
  for id in "${SSM_INSTANCES[@]}"; do
    vpc="$(aws ec2 describe-instances --region "${REGION}" --instance-ids "${id}" \
      --query 'Reservations[0].Instances[0].VpcId' --output text 2>/dev/null || true)"
    [[ "${vpc}" == "${VPC_ID}" ]] && CANDIDATES+=("${id}")
  done

  if (( ${#CANDIDATES[@]} == 0 )); then
    err "no Online SSM instances in cluster VPC ${VPC_ID}; set SSM_INSTANCE_ID explicitly"
  elif (( ${#CANDIDATES[@]} > 1 )); then
    echo "multiple SSM instances in VPC ${VPC_ID}: ${CANDIDATES[*]}" >&2
    echo "using the first (${CANDIDATES[0]}); set SSM_INSTANCE_ID to override" >&2
  fi
  INSTANCE_ID="${CANDIDATES[0]}"
fi
echo "SSM host: ${INSTANCE_ID}"

echo
echo "Starting SSM port-forward: 127.0.0.1:${LOCAL_PORT} -> ${ENDPOINT_HOST}:443"
echo "Leave THIS terminal running for the entire 'terraform apply'."
echo
echo "In another shell, point Terraform at the tunnel by EITHER:"
echo "    export TF_VAR_eks_api_local_port=${LOCAL_PORT}"
echo "  OR adding to terraform.tfvars:"
echo "    eks_api_local_port = ${LOCAL_PORT}"
echo
echo "Then run 'terraform apply' from that shell."
echo "Press Ctrl-C here to close the tunnel when the apply is finished."
echo

exec aws ssm start-session \
  --region "${REGION}" \
  --target "${INSTANCE_ID}" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${ENDPOINT_HOST}\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"
