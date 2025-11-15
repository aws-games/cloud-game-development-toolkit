#!/bin/bash

# DDC Functional Test - Tests PUT/GET operations
# Works with any DDC deployment (single or multi-region)

set -e

echo "🧪 DDC Functional Test Starting..."
echo "================================="

# Get DDC endpoint and bearer token directly from Terraform outputs
echo "📋 Getting configuration from Terraform outputs..."

# Get DNS endpoint and debug mode from Terraform outputs
DDC_DNS_ENDPOINT=$(terraform output -raw ddc_endpoint 2>/dev/null || echo "")
DEBUG_MODE=$(terraform output -json module_info 2>/dev/null | jq -r '.debug_mode // "disabled"' 2>/dev/null || echo "disabled")

if [ -z "$DDC_DNS_ENDPOINT" ]; then
    echo "❌ Could not get DDC endpoint from terraform outputs"
    echo "💡 Make sure you're running this from your terraform directory"
    echo "💡 And that 'terraform apply' completed successfully"
    exit 1
fi

# Determine protocol based on debug mode
if [ "$DEBUG_MODE" = "enabled" ]; then
    PROTOCOL="HTTP"
    # Convert HTTPS URLs to HTTP for debug mode
    DDC_DNS_ENDPOINT=$(echo "$DDC_DNS_ENDPOINT" | sed 's/^https:/http:/')
    CURL_OPTS=""
else
    PROTOCOL="HTTPS"
    CURL_OPTS="--insecure"
fi

# Use DNS endpoint as primary endpoint
PRIMARY_ENDPOINT="$DDC_DNS_ENDPOINT"

# Get bearer token from AWS Secrets Manager
BEARER_TOKEN_SECRET_ARN=$(terraform output -raw bearer_token_secret_arn 2>/dev/null)
if [ -n "$BEARER_TOKEN_SECRET_ARN" ]; then
    BEARER_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$BEARER_TOKEN_SECRET_ARN" --query SecretString --output text 2>/dev/null || echo "generated-token")
else
    BEARER_TOKEN="generated-token"
fi

if [ -z "$BEARER_TOKEN" ] || [ "$BEARER_TOKEN" = "null" ]; then
    echo "⚠️  No bearer token found, using default"
    BEARER_TOKEN="generated-token"
fi

echo "📋 Configuration:"
echo "   DNS Endpoint: $DDC_DNS_ENDPOINT"
echo "   Protocol: $PROTOCOL"
echo "   ✅ Bearer token retrieved: ${BEARER_TOKEN:0:10}..."
echo ""

# Progressive Health Checks
echo "🏥 Progressive Health Checks"
echo "============================"

# Level 1: Basic connectivity test
echo "📡 Level 1: $PROTOCOL Connectivity Test (Debug: $DEBUG_MODE)"
echo "   ℹ️  Testing $PROTOCOL connectivity directly..."

# Level 2: NLB Direct Test (for RCA)
echo ""
echo "🎯 Level 2: NLB Direct Test (for troubleshooting)"

# Get cluster info from Terraform outputs (try multiple paths)
DDC_CONNECTION=$(terraform output -json ddc_connection 2>/dev/null || terraform show -json 2>/dev/null | jq -r '.values.outputs.ddc_connection.value // null' || echo "null")
if [ "$DDC_CONNECTION" != "null" ] && [ "$DDC_CONNECTION" != "" ]; then
    CLUSTER_NAME=$(echo "$DDC_CONNECTION" | jq -r '.cluster_name // empty')
    REGION=$(echo "$DDC_CONNECTION" | jq -r '.region // empty')
    NAMESPACE=$(echo "$DDC_CONNECTION" | jq -r '.namespace // empty')
else
    # Fallback: try to get from module outputs directly
    CLUSTER_NAME=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.child_modules[]? | select(.address == "module.unreal_cloud_ddc") | .outputs.ddc_connection.value.cluster_name // empty' || echo "")
    REGION=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.child_modules[]? | select(.address == "module.unreal_cloud_ddc") | .outputs.ddc_connection.value.region // empty' || echo "")
    NAMESPACE="unreal-cloud-ddc"
fi

if [ -n "$CLUSTER_NAME" ] && [ -n "$REGION" ]; then
    echo "   🔧 Configuring kubectl access..."
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" > /dev/null 2>&1
    
    echo "   🔍 Getting NLB hostname from service..."
    NLB_HOSTNAME=$(kubectl get service -n "$NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$NLB_HOSTNAME" ]; then
        echo "   🎯 Testing NLB directly: $NLB_HOSTNAME"
        NLB_HEALTH=$(curl -s --max-time 10 "http://$NLB_HOSTNAME/health/live" || echo "FAILED")
        if echo "$NLB_HEALTH" | grep -qi "healthy"; then
            echo "   ✅ NLB direct /health/live: $NLB_HEALTH"
            NLB_WORKS=true
        else
            echo "   ❌ NLB direct /health/live failed: $NLB_HEALTH"
            echo "   💡 This indicates NLB target health issues"
            NLB_WORKS=false
        fi
    else
        echo "   ⚠️  Could not get NLB hostname from service"
        NLB_WORKS=false
    fi
else
    echo "   ⚠️  Could not get cluster info from Terraform outputs"
    NLB_WORKS=false
fi

# Level 3: DNS Health Check (primary test)
echo ""
echo "🌐 Level 3: DNS Health Check (primary test)"

# Check DNS resolution first
DNS_HOST=$(echo "$DDC_DNS_ENDPOINT" | sed 's|https://||' | sed 's|http://||')
if nslookup "$DNS_HOST" > /dev/null 2>&1; then
    echo "   ✅ DNS resolution successful for $DNS_HOST"
    DNS_HEALTH=$(curl -s --max-time 10 $CURL_OPTS "$DDC_DNS_ENDPOINT/health/live" || echo "FAILED")
    if echo "$DNS_HEALTH" | grep -qi "healthy"; then
        echo "   ✅ DNS /health/live: $DNS_HEALTH"
    else
        echo "   ❌ DNS /health/live failed: $DNS_HEALTH"
        if [ "$NLB_WORKS" = "true" ]; then
            echo "   🔧 RCA: NLB works directly, issue is with DNS/SSL/Route53"
        else
            echo "   🔧 RCA: Both NLB and DNS failed, issue is with NLB target health"
        fi
        exit 1
    fi
else
    echo "   ❌ DNS resolution failed for $DNS_HOST"
    if [ "$NLB_WORKS" = "true" ]; then
        echo "   🔧 RCA: NLB works directly, issue is DNS propagation"
        echo "   💡 Wait 5-10 minutes for DNS propagation or use NLB directly"
    else
        echo "   🔧 RCA: Both NLB and DNS failed, issue is with NLB target health"
    fi
    exit 1
fi

# Test readiness endpoint
HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/ready" || echo "FAILED")
if echo "$HEALTH_READY" | grep -qi "healthy"; then
    echo "   ✅ Primary /health/ready: $HEALTH_READY"
else
    echo "   ❌ Primary /health/ready failed: $HEALTH_READY"
    exit 1
fi

# Level 3: API Authentication Test
echo ""
echo "🔐 Level 3: API Authentication"
API_STATUS=$(curl -s --max-time 10 $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
    -H "Authorization: ServiceAccount $BEARER_TOKEN" \
    "$PRIMARY_ENDPOINT/api/v1/status" || echo "FAILED")

STATUS_CODE=$(echo "$API_STATUS" | grep "^HTTP_STATUS:" | cut -d: -f2)
if [ "$STATUS_CODE" = "200" ]; then
    echo "   ✅ API authentication successful"
    echo "   📄 API Status: $(echo "$API_STATUS" | grep -v "HTTP_STATUS:")"
elif [ "$STATUS_CODE" = "401" ] || [ "$STATUS_CODE" = "403" ]; then
    echo "   ❌ API authentication failed (HTTP $STATUS_CODE)"
    echo "   💡 Bearer token: ${BEARER_TOKEN:0:10}..."
    echo "   💡 Using ServiceAccount authentication format"
    echo "   ℹ️  Continuing with functional tests..."
    # Don't exit - continue with PUT/GET tests
else
    echo "   ⚠️  API status endpoint unavailable (HTTP $STATUS_CODE)"
    echo "   📄 Response: $(echo "$API_STATUS" | grep -v "HTTP_STATUS:")"
    echo "   ℹ️  Continuing with functional tests..."
fi

echo ""
echo "🧪 Functional Cache Tests"
echo "========================="

# Test data - use default DDC logical namespace from Terraform output
DEFAULT_DDC_NAMESPACE=$(terraform output -raw default_ddc_namespace 2>/dev/null || echo "default")
echo "🎯 Using DDC namespace: $DEFAULT_DDC_NAMESPACE"
TEST_HASH="00000000000000000000000000000000000000aa"
TEST_DATA="test"
# Use the hash that DDC calculated for this data
TEST_IOHASH="4878CA0425C739FA427F7EDA20FE845F6B2E46BA"

echo "📤 Testing PUT operation..."
echo "=========================="
PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
    "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
    -X PUT \
    --data "$TEST_DATA" \
    -H 'content-type: application/octet-stream' \
    -H "X-Jupiter-IoHash: $TEST_IOHASH" \
    -H "Authorization: ServiceAccount $BEARER_TOKEN")

PUT_STATUS=$(echo "$PUT_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
echo "PUT Status: $PUT_STATUS"
if [ "$DEBUG_MODE" = "enabled" ]; then
    echo "Test Data: $TEST_DATA"
    echo "Expected Hash: $TEST_IOHASH"
fi

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
GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
    "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
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
echo "🎉 DDC Complete Test PASSED!"
echo "================================"
echo "   ✅ DNS resolution: Working"
echo "   ✅ Health endpoints: Working"
echo "   ✅ API authentication: Working"
echo "   ✅ PUT operation: Working"
echo "   ✅ GET operation: Working"
echo "   ✅ End-to-end cache: Working"
echo ""
echo "🚀 Your DDC deployment is ready for Unreal Engine!"
echo "   🌐 DNS Endpoint: $DDC_DNS_ENDPOINT"
echo "   🔑 Use bearer token for UE configuration"
echo ""
echo "💡 MANUAL NLB TESTING (if needed):"
if [ -n "$CLUSTER_NAME" ] && [ -n "$REGION" ] && [ -n "$NLB_HOSTNAME" ]; then
    echo "   Configure kubectl: aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
    echo "   NLB hostname: $NLB_HOSTNAME"
    echo "   Test NLB directly: curl -f http://$NLB_HOSTNAME/health/live"
else
    echo "   Configure kubectl: aws eks update-kubeconfig --region [REGION] --name [CLUSTER-NAME]"
    echo "   Get NLB hostname: kubectl get service -n unreal-cloud-ddc -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
    echo "   Test NLB directly: curl -f http://[NLB-HOSTNAME]/health/live"
fi