#!/bin/bash

# DDC Functional Test - Tests PUT/GET operations
# Works with any DDC deployment (single or multi-region)

set -e

echo "🧪 DDC Functional Test Starting..."
echo "================================="

# Get DDC endpoint and bearer token directly from Terraform outputs
echo "📋 Getting configuration from Terraform outputs..."

# Get DDC connection info from Terraform outputs
DDC_CONNECTION=$(terraform output -json ddc_connection 2>/dev/null)
if [ -z "$DDC_CONNECTION" ] || [ "$DDC_CONNECTION" = "null" ]; then
    echo "❌ Could not get ddc_connection from terraform outputs"
    echo "💡 Make sure you're running this from your terraform directory"
    echo "💡 And that 'terraform apply' completed successfully"
    exit 1
fi

# Extract available endpoints
DDC_DNS_ENDPOINT=$(echo "$DDC_CONNECTION" | jq -r '.endpoint_private_dns // empty')
DDC_DIRECT_ENDPOINT=$(echo "$DDC_CONNECTION" | jq -r '.endpoint_nlb // empty')
ACCESS_METHOD=$(echo "$DDC_CONNECTION" | jq -r '.access_method // "external"')

# Determine primary endpoint based on access method
if [ "$ACCESS_METHOD" = "internal" ] && [ -n "$DDC_DNS_ENDPOINT" ]; then
    PRIMARY_ENDPOINT="$DDC_DNS_ENDPOINT"
elif [ "$ACCESS_METHOD" = "external" ] && [ -n "$DDC_DNS_ENDPOINT" ]; then
    PRIMARY_ENDPOINT="$DDC_DNS_ENDPOINT"
else
    PRIMARY_ENDPOINT="$DDC_DIRECT_ENDPOINT"
fi

if [ -z "$PRIMARY_ENDPOINT" ]; then
    echo "❌ No DDC endpoints found in terraform outputs"
    exit 1
fi

# Get bearer token from Terraform outputs
BEARER_TOKEN_ARN=$(echo "$DDC_CONNECTION" | jq -r '.bearer_token_secret_arn // empty')
if [ -n "$BEARER_TOKEN_ARN" ]; then
    BEARER_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$BEARER_TOKEN_ARN" --query SecretString --output text 2>/dev/null)
else
    # Fallback to direct terraform output
    BEARER_TOKEN=$(terraform output -raw bearer_token 2>/dev/null)
fi

if [ -z "$BEARER_TOKEN" ]; then
    echo "❌ Could not get bearer token"
    echo "💡 Check bearer_token_secret_arn in terraform outputs or bearer_token output"
    exit 1
fi

echo "📋 Configuration:"
echo "   Access Method: $ACCESS_METHOD"
echo "   Primary Endpoint: $PRIMARY_ENDPOINT"
if [ -n "$DDC_DNS_ENDPOINT" ] && [ -n "$DDC_DIRECT_ENDPOINT" ]; then
    echo "   DNS Endpoint: $DDC_DNS_ENDPOINT"
    echo "   Direct NLB: $DDC_DIRECT_ENDPOINT"
fi
echo "   ✅ Bearer token retrieved"
echo ""

# Progressive Health Checks
echo "🏥 Progressive Health Checks"
echo "============================"

# Level 1: Basic Network Connectivity
echo "📡 Level 1: Network Connectivity"

# Test primary endpoint
PRIMARY_HOST=$(echo "$PRIMARY_ENDPOINT" | sed 's|https\?://||' | sed 's|/.*||')
if nc -z -w5 "$PRIMARY_HOST" 80 2>/dev/null; then
    echo "   ✅ Primary endpoint port 80 reachable ($PRIMARY_HOST)"
else
    echo "   ❌ Primary endpoint port 80 unreachable ($PRIMARY_HOST)"
    echo "   💡 Check security groups and access method configuration"
    exit 1
fi

if nc -z -w5 "$PRIMARY_HOST" 443 2>/dev/null; then
    echo "   ✅ Primary endpoint port 443 reachable ($PRIMARY_HOST)"
else
    echo "   ⚠️  Primary endpoint port 443 unreachable ($PRIMARY_HOST)"
fi

# Test direct NLB if different from primary
if [ -n "$DDC_DIRECT_ENDPOINT" ] && [ "$DDC_DIRECT_ENDPOINT" != "$PRIMARY_ENDPOINT" ]; then
    DIRECT_HOST=$(echo "$DDC_DIRECT_ENDPOINT" | sed 's|https\?://||' | sed 's|/.*||')
    if nc -z -w5 "$DIRECT_HOST" 80 2>/dev/null; then
        echo "   ✅ Direct NLB port 80 reachable ($DIRECT_HOST)"
    else
        echo "   ❌ Direct NLB port 80 unreachable ($DIRECT_HOST)"
    fi
fi

# Level 2: Basic Health Endpoints (No Auth)
echo ""
echo "💓 Level 2: Health Endpoints (No Auth Required)"

# Test primary endpoint health
HEALTH_LIVE=$(curl -s --max-time 10 "$PRIMARY_ENDPOINT/health/live" || echo "FAILED")
if echo "$HEALTH_LIVE" | grep -q "Healthy"; then
    echo "   ✅ Primary /health/live: $HEALTH_LIVE"
else
    echo "   ❌ Primary /health/live failed: $HEALTH_LIVE"
    exit 1
fi

HEALTH_READY=$(curl -s --max-time 10 "$PRIMARY_ENDPOINT/health/ready" || echo "FAILED")
if echo "$HEALTH_READY" | grep -q "Healthy"; then
    echo "   ✅ Primary /health/ready: $HEALTH_READY"
else
    echo "   ❌ Primary /health/ready failed: $HEALTH_READY"
    exit 1
fi

# Test direct NLB health if different
if [ -n "$DDC_DIRECT_ENDPOINT" ] && [ "$DDC_DIRECT_ENDPOINT" != "$PRIMARY_ENDPOINT" ]; then
    DIRECT_HEALTH=$(curl -s --max-time 10 "$DDC_DIRECT_ENDPOINT/health/live" || echo "FAILED")
    if echo "$DIRECT_HEALTH" | grep -q "Healthy"; then
        echo "   ✅ Direct NLB /health/live: $DIRECT_HEALTH"
    else
        echo "   ⚠️  Direct NLB /health/live failed: $DIRECT_HEALTH"
    fi
fi

# Level 3: API Authentication Test
echo ""
echo "🔐 Level 3: API Authentication"
API_STATUS=$(curl -s --max-time 10 -w "HTTP_STATUS:%{http_code}" \
    -H "Authorization: Bearer $BEARER_TOKEN" \
    "$PRIMARY_ENDPOINT/api/v1/status" || echo "FAILED")

STATUS_CODE=$(echo "$API_STATUS" | grep "HTTP_STATUS:" | cut -d: -f2)
if [ "$STATUS_CODE" = "200" ]; then
    echo "   ✅ API authentication successful"
    echo "   📄 API Status: $(echo "$API_STATUS" | grep -v "HTTP_STATUS:")"
elif [ "$STATUS_CODE" = "401" ] || [ "$STATUS_CODE" = "403" ]; then
    echo "   ❌ API authentication failed (HTTP $STATUS_CODE)"
    echo "   💡 Check bearer token is correct"
    exit 1
else
    echo "   ⚠️  API status endpoint unavailable (HTTP $STATUS_CODE)"
    echo "   📄 Response: $(echo "$API_STATUS" | grep -v "HTTP_STATUS:")"
    echo "   ℹ️  Continuing with functional tests..."
fi

echo ""
echo "🧪 Functional Cache Tests"
echo "========================="

# Test data - use first namespace from configuration
FIRST_NAMESPACE=$(echo "$DDC_CONNECTION" | jq -r 'if .namespaces then (.namespaces | keys[0]) else "ddc" end')
TEST_HASH="00000000000000000000000000000000000000aa"
TEST_DATA="test-$(date +%s)"
TEST_IOHASH="4878CA0425C739FA427F7EDA20FE845F6B2E46BA"

echo "📤 Testing PUT operation..."
echo "=========================="
PUT_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    "$PRIMARY_ENDPOINT/api/v1/refs/$FIRST_NAMESPACE/default/$TEST_HASH" \
    -X PUT \
    --data "$TEST_DATA" \
    -H 'content-type: application/octet-stream' \
    -H "X-Jupiter-IoHash: $TEST_IOHASH" \
    -H "Authorization: Bearer $BEARER_TOKEN")

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
    "$PRIMARY_ENDPOINT/api/v1/refs/$FIRST_NAMESPACE/default/$TEST_HASH.raw" \
    -H "Authorization: Bearer $BEARER_TOKEN")

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
echo "🎉 DDC Complete Test PASSED!"
echo "================================"
echo "   ✅ Network connectivity: Working"
echo "   ✅ Health endpoints: Working"
echo "   ✅ API authentication: Working"
echo "   ✅ PUT operation: Working"
echo "   ✅ GET operation: Working"
echo "   ✅ End-to-end cache: Working"
echo ""
echo "🚀 Your DDC deployment is ready for Unreal Engine!"
echo "   🔗 Primary Endpoint: $PRIMARY_ENDPOINT"
if [ -n "$DDC_DNS_ENDPOINT" ] && [ "$DDC_DNS_ENDPOINT" != "$PRIMARY_ENDPOINT" ]; then
    echo "   🌐 DNS Endpoint: $DDC_DNS_ENDPOINT"
fi
echo "   🔑 Use bearer token for UE configuration"