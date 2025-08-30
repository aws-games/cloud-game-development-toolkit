#!/bin/bash

# DDC Functional Test - Tests PUT/GET operations
# Works with any DDC deployment (single or multi-region)

set -e

echo "🧪 DDC Functional Test Starting..."
echo "================================="

# Get project prefix and name from terraform outputs (with fallbacks)
PROJECT_PREFIX=$(terraform output -raw project_prefix 2>/dev/null || echo "cgd")
DDC_NAME=$(terraform output -raw name 2>/dev/null || echo "unreal-cloud-ddc")

# Construct resource names using same pattern as module
NLB_NAME="${PROJECT_PREFIX}-${DDC_NAME}"
SECRET_NAME="${PROJECT_PREFIX}-${DDC_NAME}-bearer-token"

echo "📋 Configuration:"
echo "   Project Prefix: $PROJECT_PREFIX"
echo "   DDC Name: $DDC_NAME"
echo "   NLB Name: $NLB_NAME"
echo "   Secret Name: $SECRET_NAME"
echo ""

# Get NLB DNS name
echo "🔗 Getting NLB DNS name..."
NLB_DNS=$(aws elbv2 describe-load-balancers --names "$NLB_NAME" --query 'LoadBalancers[*].DNSName' --output text)
echo "   NLB DNS: $NLB_DNS"

# Get bearer token
echo "🔑 Getting bearer token..."
BEARER_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query 'SecretString' --output text)
echo "   ✅ Bearer token retrieved"
echo ""

# Test data
TEST_HASH="00000000000000000000000000000000000000aa"
TEST_DATA="test"
TEST_IOHASH="4878CA0425C739FA427F7EDA20FE845F6B2E46BA"

echo "📤 Testing PUT operation..."
echo "=========================="
PUT_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    "http://$NLB_DNS/api/v1/refs/ddc/default/$TEST_HASH" \
    -X PUT \
    --data "$TEST_DATA" \
    -H 'content-type: application/octet-stream' \
    -H "X-Jupiter-IoHash: $TEST_IOHASH" \
    -H "Authorization: ServiceAccount $BEARER_TOKEN")

PUT_STATUS=$(echo "$PUT_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
echo "PUT Status: $PUT_STATUS"

if [ "$PUT_STATUS" = "200" ] || [ "$PUT_STATUS" = "201" ]; then
    echo "✅ PUT operation successful"
else
    echo "❌ PUT operation failed"
    echo "$PUT_RESPONSE"
    exit 1
fi

echo ""
echo "📥 Testing GET operation..."
echo "=========================="
GET_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    "http://$NLB_DNS/api/v1/refs/ddc/default/$TEST_HASH.json" \
    -H "Authorization: ServiceAccount $BEARER_TOKEN")

GET_STATUS=$(echo "$GET_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
echo "GET Status: $GET_STATUS"

if [ "$GET_STATUS" = "200" ]; then
    echo "✅ GET operation successful"
    echo "📄 Response data:"
    echo "$GET_RESPONSE" | grep -v "HTTP_STATUS:"
else
    echo "❌ GET operation failed"
    echo "$GET_RESPONSE"
    exit 1
fi

echo ""
echo "🎉 DDC Functional Test PASSED!"
echo "   ✅ PUT operation: Working"
echo "   ✅ GET operation: Working"
echo "   ✅ Authentication: Working"
echo "   ✅ Cache functionality: Working"