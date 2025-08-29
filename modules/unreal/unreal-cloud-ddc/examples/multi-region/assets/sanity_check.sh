#!/bin/bash

# Multi-region sanity check for Unreal Cloud DDC
# This script tests both regions and verifies replication is working

set -e

# Configuration - modify these if your setup differs
PRIMARY_REGION=${PRIMARY_REGION:-"us-east-1"}
SECONDARY_REGION=${SECONDARY_REGION:-"us-west-2"}
LB_NAME="cgd-unreal-cloud-ddc"
SECRET_NAME="unreal-cloud-ddc-token"

echo "=========================================="
echo "Multi-Region Unreal Cloud DDC Sanity Check"
echo "Primary Region: $PRIMARY_REGION"
echo "Secondary Region: $SECONDARY_REGION"
echo "=========================================="

# Get load balancer DNS names for both regions
echo "Getting load balancer DNS names..."
primary_nlb_dns=$(aws elbv2 describe-load-balancers --names $LB_NAME --region $PRIMARY_REGION --query 'LoadBalancers[0].DNSName' --output text)
secondary_nlb_dns=$(aws elbv2 describe-load-balancers --names $LB_NAME --region $SECONDARY_REGION --query 'LoadBalancers[0].DNSName' --output text)

echo "Primary NLB: $primary_nlb_dns"
echo "Secondary NLB: $secondary_nlb_dns"

# Get bearer token (assuming it's in the primary region)
echo "Getting bearer token..."
bearer_token=$(aws secretsmanager get-secret-value --secret-id $SECRET_NAME --region $PRIMARY_REGION --query 'SecretString' --output text)

# Test data
test_hash="00000000000000000000000000000000000000bb"
test_data="multi-region-test-$(date +%s)"

echo ""
echo "=========================================="
echo "Step 1: PUT data to PRIMARY region"
echo "=========================================="
curl -s http://$primary_nlb_dns/api/v1/refs/ddc/default/$test_hash \
  -X PUT \
  --data "$test_data" \
  -H 'content-type: application/octet-stream' \
  -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' \
  -H "Authorization: ServiceAccount $bearer_token" \
  -w "\nHTTP Status: %{http_code}\n"

echo ""
echo "=========================================="
echo "Step 2: GET data from PRIMARY region"
echo "=========================================="
primary_response=$(curl -s http://$primary_nlb_dns/api/v1/refs/ddc/default/$test_hash.json \
  -H "Authorization: ServiceAccount $bearer_token")
echo "Primary response: $primary_response"

echo ""
echo "=========================================="
echo "Step 3: Wait for replication (30 seconds)"
echo "=========================================="
sleep 30

echo ""
echo "=========================================="
echo "Step 4: GET data from SECONDARY region"
echo "=========================================="
secondary_response=$(curl -s http://$secondary_nlb_dns/api/v1/refs/ddc/default/$test_hash.json \
  -H "Authorization: ServiceAccount $bearer_token" \
  -w "\nHTTP Status: %{http_code}")
echo "Secondary response: $secondary_response"

echo ""
echo "=========================================="
echo "Step 5: Verify replication worked"
echo "=========================================="
if echo "$secondary_response" | grep -q "200"; then
    echo "✅ SUCCESS: Data replicated to secondary region!"
else
    echo "❌ FAILED: Data not found in secondary region"
    echo "This could indicate replication issues or the data hasn't replicated yet"
    exit 1
fi

echo ""
echo "=========================================="
echo "Multi-region sanity check completed!"
echo "=========================================="