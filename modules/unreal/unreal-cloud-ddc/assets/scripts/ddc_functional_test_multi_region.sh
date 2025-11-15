#!/bin/bash

# DDC Multi-Region Functional Test - Tests cross-region replication
# PUT to primary region, wait for replication, GET from secondary region

set -e

echo "🌍 DDC Multi-Region Functional Test Starting..."
echo "==============================================="
echo "📋 This test validates DDC cross-region replication:"
echo "   1. PUT data to primary region"
echo "   2. Wait for DDC replication (via ScyllaDB)"
echo "   3. GET data from secondary region"
echo "   4. Verify data matches"
echo ""

# Function to test endpoint health
test_endpoint_health() {
    local endpoint="$1"
    local region_name="$2"
    local bearer_token="$3"
    local curl_opts="$4"
    
    echo "🏥 Testing $region_name endpoint health..."
    
    # Test health endpoint
    HEALTH_LIVE=$(curl -s --max-time 10 $curl_opts "$endpoint/health/live" || echo "FAILED")
    if echo "$HEALTH_LIVE" | grep -qi "healthy"; then
        echo "   ✅ $region_name /health/live: $HEALTH_LIVE"
    else
        echo "   ❌ $region_name /health/live failed: $HEALTH_LIVE"
        return 1
    fi
    
    return 0
}

# Legacy function for backward compatibility
test_region() {
    local region_name="$1"
    local ddc_endpoint="$2"
    local ddc_direct_endpoint="$3"
    local bearer_token="$4"
    local debug_mode="$5"
    
    echo ""
    echo "🌎 Testing Region: $region_name"
    echo "================================"
    
    # Determine protocol based on debug mode
    if [ "$debug_mode" = "enabled" ]; then
        PROTOCOL="HTTP"
        # Convert HTTPS URLs to HTTP for debug mode
        ddc_endpoint=$(echo "$ddc_endpoint" | sed 's/^https:/http:/')
        ddc_direct_endpoint=$(echo "$ddc_direct_endpoint" | sed 's/^https:/http:/')
        CURL_OPTS=""
    else
        PROTOCOL="HTTPS"
        CURL_OPTS="--insecure"
    fi
    
    # Use DNS endpoint if available, otherwise direct NLB
    if [ -n "$ddc_endpoint" ]; then
        PRIMARY_ENDPOINT="$ddc_endpoint"
    else
        PRIMARY_ENDPOINT="$ddc_direct_endpoint"
    fi
    
    echo "📋 Configuration:"
    echo "   Primary Endpoint: $PRIMARY_ENDPOINT"
    if [ -n "$ddc_endpoint" ] && [ -n "$ddc_direct_endpoint" ]; then
        echo "   DNS Endpoint: $ddc_endpoint"
        echo "   Direct NLB: $ddc_direct_endpoint"
    fi
    echo "   ✅ Bearer token: ${bearer_token:0:10}..."
    echo ""
    
    # Progressive Health Checks
    echo "🏥 Progressive Health Checks"
    echo "============================"
    
    # Level 1: Basic connectivity test
    echo "📡 Level 1: $PROTOCOL Connectivity Test (Debug: $debug_mode)"
    echo "   ℹ️  Testing $PROTOCOL connectivity directly..."
    
    # Level 2: Basic Health Endpoints (No Auth)
    echo ""
    echo "💓 Level 2: Health Endpoints (No Auth Required)"
    
    # Get DNS host and IP for --resolve (bypassing local DNS cache)
    # Using Cloudflare DNS for reliable, fast DNS resolution
    DNS_HOST=$(echo "$PRIMARY_ENDPOINT" | sed 's|https://||' | sed 's|http://||')
    DNS_IP=$(dig @1.1.1.1 +short "$DNS_HOST" | head -1)
    
    # Test primary endpoint health using --resolve if DNS available
    if [ -n "$DNS_IP" ] && [[ "$PRIMARY_ENDPOINT" == *"$DNS_HOST"* ]]; then
        if [[ "$PRIMARY_ENDPOINT" == https://* ]]; then
            HEALTH_LIVE=$(curl -s --max-time 10 $CURL_OPTS --resolve "$DNS_HOST:443:$DNS_IP" "$PRIMARY_ENDPOINT/health/live" || echo "FAILED")
        else
            HEALTH_LIVE=$(curl -s --max-time 10 $CURL_OPTS --resolve "$DNS_HOST:80:$DNS_IP" "$PRIMARY_ENDPOINT/health/live" || echo "FAILED")
        fi
    else
        HEALTH_LIVE=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/live" || echo "FAILED")
    fi
    if echo "$HEALTH_LIVE" | grep -qi "healthy"; then
        echo "   ✅ Primary /health/live: $HEALTH_LIVE"
    else
        echo "   ❌ Primary /health/live failed: $HEALTH_LIVE"
        return 1
    fi
    
    # Test readiness endpoint using --resolve if DNS available
    if [ -n "$DNS_IP" ] && [[ "$PRIMARY_ENDPOINT" == *"$DNS_HOST"* ]]; then
        if [[ "$PRIMARY_ENDPOINT" == https://* ]]; then
            HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS --resolve "$DNS_HOST:443:$DNS_IP" "$PRIMARY_ENDPOINT/health/ready" || echo "FAILED")
        else
            HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS --resolve "$DNS_HOST:80:$DNS_IP" "$PRIMARY_ENDPOINT/health/ready" || echo "FAILED")
        fi
    else
        HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/ready" || echo "FAILED")
    fi
    if echo "$HEALTH_READY" | grep -qi "healthy"; then
        echo "   ✅ Primary /health/ready: $HEALTH_READY"
    else
        echo "   ❌ Primary /health/ready failed: $HEALTH_READY"
        return 1
    fi
    
    # Test direct NLB health if different
    if [ -n "$ddc_direct_endpoint" ] && [ "$ddc_direct_endpoint" != "$PRIMARY_ENDPOINT" ]; then
        DIRECT_HEALTH=$(curl -s --max-time 10 $CURL_OPTS "$ddc_direct_endpoint/health/live" || echo "FAILED")
        if echo "$DIRECT_HEALTH" | grep -qi "healthy"; then
            echo "   ✅ Direct NLB /health/live: $DIRECT_HEALTH"
        else
            echo "   ⚠️  Direct NLB /health/live failed: $DIRECT_HEALTH"
        fi
    fi
    
    # Level 3: API Authentication Test
    echo ""
    echo "🔐 Level 3: API Authentication"
    # Test API status using --resolve if DNS available
    if [ -n "$DNS_IP" ] && [[ "$PRIMARY_ENDPOINT" == *"$DNS_HOST"* ]]; then
        if [[ "$PRIMARY_ENDPOINT" == https://* ]]; then
            API_STATUS=$(curl -s --max-time 10 $CURL_OPTS -w "HTTP_STATUS:%{http_code}" \
                --resolve "$DNS_HOST:443:$DNS_IP" \
                -H "Authorization: ServiceAccount $bearer_token" \
                "$PRIMARY_ENDPOINT/api/v1/status" || echo "FAILED")
        else
            API_STATUS=$(curl -s --max-time 10 $CURL_OPTS -w "HTTP_STATUS:%{http_code}" \
                --resolve "$DNS_HOST:80:$DNS_IP" \
                -H "Authorization: ServiceAccount $bearer_token" \
                "$PRIMARY_ENDPOINT/api/v1/status" || echo "FAILED")
        fi
    else
        API_STATUS=$(curl -s --max-time 10 $CURL_OPTS -w "HTTP_STATUS:%{http_code}" \
            -H "Authorization: ServiceAccount $bearer_token" \
            "$PRIMARY_ENDPOINT/api/v1/status" || echo "FAILED")
    fi
    
    STATUS_CODE=$(echo "$API_STATUS" | grep "HTTP_STATUS:" | cut -d: -f2)
    if [ "$STATUS_CODE" = "200" ]; then
        echo "   ✅ API authentication successful"
        echo "   📄 API Status: $(echo "$API_STATUS" | grep -v "HTTP_STATUS:")"
    elif [ "$STATUS_CODE" = "401" ] || [ "$STATUS_CODE" = "403" ]; then
        echo "   ❌ API authentication failed (HTTP $STATUS_CODE)"
        echo "   💡 Bearer token: ${bearer_token:0:10}..."
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
    # Use region-specific test hash to avoid cross-region conflicts
    TEST_HASH="00000000000000000000000000000000000000$(echo "$region_name" | md5sum | cut -c1-2)"
    TEST_DATA="test-$region_name"
    # Calculate hash for region-specific data
    TEST_IOHASH=$(echo -n "$TEST_DATA" | sha1sum | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
    
    echo "📤 Testing PUT operation..."
    echo "=========================="
    # PUT operation using --resolve if DNS available
    if [ -n "$DNS_IP" ] && [[ "$PRIMARY_ENDPOINT" == *"$DNS_HOST"* ]]; then
        if [[ "$PRIMARY_ENDPOINT" == https://* ]]; then
            PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
                --resolve "$DNS_HOST:443:$DNS_IP" \
                "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
                -X PUT \
                --data "$TEST_DATA" \
                -H 'content-type: application/octet-stream' \
                -H "X-Jupiter-IoHash: $TEST_IOHASH" \
                -H "Authorization: ServiceAccount $bearer_token")
        else
            PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
                --resolve "$DNS_HOST:80:$DNS_IP" \
                "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
                -X PUT \
                --data "$TEST_DATA" \
                -H 'content-type: application/octet-stream' \
                -H "X-Jupiter-IoHash: $TEST_IOHASH" \
                -H "Authorization: ServiceAccount $bearer_token")
        fi
    else
        PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
            "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
            -X PUT \
            --data "$TEST_DATA" \
            -H 'content-type: application/octet-stream' \
            -H "X-Jupiter-IoHash: $TEST_IOHASH" \
            -H "Authorization: ServiceAccount $bearer_token")
    fi
    
    PUT_STATUS=$(echo "$PUT_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    echo "PUT Status: $PUT_STATUS"
    if [ "$debug_mode" = "enabled" ]; then
        echo "Test Data: $TEST_DATA"
        echo "Expected Hash: $TEST_IOHASH"
    fi
    
    if [ "$PUT_STATUS" = "200" ] || [ "$PUT_STATUS" = "201" ]; then
        echo "✅ PUT operation successful"
    else
        echo "❌ PUT operation failed"
        echo "$PUT_RESPONSE"
        return 1
    fi
    
    echo ""
    echo "📥 Testing GET operation..."
    echo "=========================="
    # GET operation using --resolve if DNS available
    if [ -n "$DNS_IP" ] && [[ "$PRIMARY_ENDPOINT" == *"$DNS_HOST"* ]]; then
        if [[ "$PRIMARY_ENDPOINT" == https://* ]]; then
            GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
                --resolve "$DNS_HOST:443:$DNS_IP" \
                "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
                -H "Authorization: ServiceAccount $bearer_token")
        else
            GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
                --resolve "$DNS_HOST:80:$DNS_IP" \
                "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
                -H "Authorization: ServiceAccount $bearer_token")
        fi
    else
        GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
            "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
            -H "Authorization: ServiceAccount $bearer_token")
    fi
    
    GET_STATUS=$(echo "$GET_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    echo "GET Status: $GET_STATUS"
    
    if [ "$GET_STATUS" = "200" ]; then
        echo "✅ GET operation successful"
        echo "📄 Response data:"
        echo "$GET_RESPONSE" | grep -v "HTTP_STATUS:"
    else
        echo "❌ GET operation failed"
        echo "$GET_RESPONSE"
        return 1
    fi
    
    echo ""
    echo "🎉 Region $region_name Test PASSED!"
    echo "=================================="
    echo "   ✅ Network connectivity: Working"
    echo "   ✅ Health endpoints: Working"
    echo "   ✅ API authentication: Working"
    echo "   ✅ PUT operation: Working"
    echo "   ✅ GET operation: Working"
    echo "   ✅ End-to-end cache: Working"
    
    return 0
}

# Get configuration from Terraform outputs
echo "📋 Getting configuration from Terraform outputs..."

# Test if Terraform is working first
TERRAFORM_TEST=$(terraform version 2>/dev/null || echo "FAILED")
if echo "$TERRAFORM_TEST" | grep -q "FAILED"; then
    echo "❌ Terraform not found or not working"
    echo "💡 Install Terraform or check PATH"
    exit 1
fi

# Test if we can read Terraform outputs
TERRAFORM_OUTPUT_TEST=$(terraform output 2>&1 || echo "FAILED")
if echo "$TERRAFORM_OUTPUT_TEST" | grep -q "Error\|FAILED"; then
    echo "❌ Terraform configuration has errors:"
    echo "$TERRAFORM_OUTPUT_TEST"
    echo ""
    echo "🔧 TROUBLESHOOTING STEPS:"
    echo "   1. Run 'terraform refresh' to sync state with AWS"
    echo "   2. If that fails, run 'terraform validate' to check syntax"
    echo "   3. If validation fails, fix Terraform syntax errors"
    echo "   4. Run 'terraform apply' if state is out of sync"
    exit 1
fi

# Get primary region configuration
PRIMARY_DDC_DNS_ENDPOINT=$(terraform output -raw primary_ddc_endpoint 2>/dev/null || echo "")
PRIMARY_DDC_DIRECT_ENDPOINT=$(terraform output -raw primary_ddc_endpoint_nlb 2>/dev/null || echo "")
PRIMARY_REGION=$(terraform output -raw primary_region 2>/dev/null || echo "primary")

# Get secondary region configuration
SECONDARY_DDC_DNS_ENDPOINT=$(terraform output -raw secondary_ddc_endpoint 2>/dev/null || echo "")
SECONDARY_DDC_DIRECT_ENDPOINT=$(terraform output -raw secondary_ddc_endpoint_nlb 2>/dev/null || echo "")
SECONDARY_REGION=$(terraform output -raw secondary_region 2>/dev/null || echo "secondary")

# Get debug mode (should be same for both regions)
DEBUG_MODE=$(terraform output -json primary_module_info 2>/dev/null | jq -r '.debug_mode // "disabled"' 2>/dev/null || echo "disabled")

# Validate we have endpoints for both regions
if [ -z "$PRIMARY_DDC_DNS_ENDPOINT" ] && [ -z "$PRIMARY_DDC_DIRECT_ENDPOINT" ]; then
    echo "❌ Could not get primary region DDC endpoints from terraform outputs"
    echo "💡 Make sure you're running this from your multi-region terraform directory"
    echo "💡 And that 'terraform apply' completed successfully"
    echo "💡 Try 'terraform refresh' to sync state with AWS"
    exit 1
fi

if [ -z "$SECONDARY_DDC_DNS_ENDPOINT" ] && [ -z "$SECONDARY_DDC_DIRECT_ENDPOINT" ]; then
    echo "❌ Could not get secondary region DDC endpoints from terraform outputs"
    echo "💡 Make sure you're running this from your multi-region terraform directory"
    echo "💡 And that 'terraform apply' completed successfully"
    echo "💡 Try 'terraform refresh' to sync state with AWS"
    exit 1
fi

# Get debug mode and DDC namespace
DEBUG_MODE=$(terraform output -json primary_module_info 2>/dev/null | jq -r '.debug_mode // "disabled"' 2>/dev/null || echo "disabled")
DEFAULT_DDC_NAMESPACE=$(terraform output -raw default_ddc_namespace 2>/dev/null || echo "default")

# Get bearer token (should be shared across regions)
BEARER_TOKEN_SECRET_ARN=$(terraform output -raw primary_bearer_token_secret_arn 2>/dev/null || terraform output -raw bearer_token_secret_arn 2>/dev/null)
if [ -n "$BEARER_TOKEN_SECRET_ARN" ]; then
    BEARER_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$BEARER_TOKEN_SECRET_ARN" --query SecretString --output text 2>/dev/null || echo "generated-token")
else
    BEARER_TOKEN="generated-token"
fi

if [ -z "$BEARER_TOKEN" ] || [ "$BEARER_TOKEN" = "null" ]; then
    echo "⚠️  No bearer token found, using default"
    BEARER_TOKEN="generated-token"
fi

# Determine protocol and curl options
if [ "$DEBUG_MODE" = "enabled" ]; then
    PROTOCOL="HTTP"
    PRIMARY_DDC_DNS_ENDPOINT=$(echo "$PRIMARY_DDC_DNS_ENDPOINT" | sed 's/^https:/http:/')
    PRIMARY_DDC_DIRECT_ENDPOINT=$(echo "$PRIMARY_DDC_DIRECT_ENDPOINT" | sed 's/^https:/http:/')
    SECONDARY_DDC_DNS_ENDPOINT=$(echo "$SECONDARY_DDC_DNS_ENDPOINT" | sed 's/^https:/http:/')
    SECONDARY_DDC_DIRECT_ENDPOINT=$(echo "$SECONDARY_DDC_DIRECT_ENDPOINT" | sed 's/^https:/http:/')
    CURL_OPTS=""
else
    PROTOCOL="HTTPS"
    CURL_OPTS="--insecure"
fi

# Use DNS endpoint if available, otherwise direct NLB
if [ -n "$PRIMARY_DDC_DNS_ENDPOINT" ]; then
    PRIMARY_ENDPOINT="$PRIMARY_DDC_DNS_ENDPOINT"
else
    PRIMARY_ENDPOINT="$PRIMARY_DDC_DIRECT_ENDPOINT"
fi

if [ -n "$SECONDARY_DDC_DNS_ENDPOINT" ]; then
    SECONDARY_ENDPOINT="$SECONDARY_DDC_DNS_ENDPOINT"
else
    SECONDARY_ENDPOINT="$SECONDARY_DDC_DIRECT_ENDPOINT"
fi

echo "📋 Multi-Region Configuration:"
echo "   Primary Region: $PRIMARY_REGION ($PRIMARY_ENDPOINT)"
echo "   Secondary Region: $SECONDARY_REGION ($SECONDARY_ENDPOINT)"
echo "   Protocol: $PROTOCOL (Debug: $DEBUG_MODE)"
echo "   DDC Namespace: $DEFAULT_DDC_NAMESPACE"
echo ""

# Test endpoint health first
echo "🏥 Health Check Phase"
echo "===================="
if ! test_endpoint_health "$PRIMARY_ENDPOINT" "$PRIMARY_REGION" "$BEARER_TOKEN" "$CURL_OPTS"; then
    echo "❌ Primary region health check failed"
    exit 1
fi

if ! test_endpoint_health "$SECONDARY_ENDPOINT" "$SECONDARY_REGION" "$BEARER_TOKEN" "$CURL_OPTS"; then
    echo "❌ Secondary region health check failed"
    exit 1
fi

echo "✅ Both regions are healthy"
echo ""

# Cross-region replication test
echo "🔄 Cross-Region Replication Test"
echo "==============================="

# Generate test data
TEST_HASH="00000000000000000000000000000000000000aa"
TEST_DATA="multi-region-test-$(date +%s)"
TEST_IOHASH=$(echo -n "$TEST_DATA" | sha1sum | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')

echo "📤 Step 1: PUT data to primary region ($PRIMARY_REGION)..."
# Get DNS info for primary endpoint (using Cloudflare DNS)
PRIMARY_DNS_HOST=$(echo "$PRIMARY_ENDPOINT" | sed 's|https://||' | sed 's|http://||')
PRIMARY_DNS_IP=$(dig @1.1.1.1 +short "$PRIMARY_DNS_HOST" | head -1)

if [ -n "$PRIMARY_DNS_IP" ] && [[ "$PRIMARY_ENDPOINT" == *"$PRIMARY_DNS_HOST"* ]]; then
    if [[ "$PRIMARY_ENDPOINT" == https://* ]]; then
        PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
            --resolve "$PRIMARY_DNS_HOST:443:$PRIMARY_DNS_IP" \
            "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
            -X PUT \
            --data "$TEST_DATA" \
            -H 'content-type: application/octet-stream' \
            -H "X-Jupiter-IoHash: $TEST_IOHASH" \
            -H "Authorization: ServiceAccount $BEARER_TOKEN")
    else
        PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
            --resolve "$PRIMARY_DNS_HOST:80:$PRIMARY_DNS_IP" \
            "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
            -X PUT \
            --data "$TEST_DATA" \
            -H 'content-type: application/octet-stream' \
            -H "X-Jupiter-IoHash: $TEST_IOHASH" \
            -H "Authorization: ServiceAccount $BEARER_TOKEN")
    fi
else
    PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
        "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
        -X PUT \
        --data "$TEST_DATA" \
        -H 'content-type: application/octet-stream' \
        -H "X-Jupiter-IoHash: $TEST_IOHASH" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN")
fi

PUT_STATUS=$(echo "$PUT_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
if [ "$PUT_STATUS" = "200" ] || [ "$PUT_STATUS" = "201" ]; then
    echo "✅ PUT to primary region successful"
else
    echo "❌ PUT to primary region failed (HTTP $PUT_STATUS)"
    echo "$PUT_RESPONSE"
    exit 1
fi

echo ""
echo "⏳ Step 2: Waiting for ScyllaDB cross-region replication..."
echo "   ℹ️  Waiting 60 seconds for data to replicate to secondary region"
for i in {1..60}; do
    echo -n "."
    sleep 1
    if [ $((i % 10)) -eq 0 ]; then
        echo " ${i}s"
    fi
done
echo ""
echo "✅ Replication wait complete"

echo ""
echo "📥 Step 3: GET data from secondary region ($SECONDARY_REGION)..."
# Get DNS info for secondary endpoint (using Cloudflare DNS)
SECONDARY_DNS_HOST=$(echo "$SECONDARY_ENDPOINT" | sed 's|https://||' | sed 's|http://||')
SECONDARY_DNS_IP=$(dig @1.1.1.1 +short "$SECONDARY_DNS_HOST" | head -1)

if [ -n "$SECONDARY_DNS_IP" ] && [[ "$SECONDARY_ENDPOINT" == *"$SECONDARY_DNS_HOST"* ]]; then
    if [[ "$SECONDARY_ENDPOINT" == https://* ]]; then
        GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
            --resolve "$SECONDARY_DNS_HOST:443:$SECONDARY_DNS_IP" \
            "$SECONDARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
            -H "Authorization: ServiceAccount $BEARER_TOKEN")
    else
        GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
            --resolve "$SECONDARY_DNS_HOST:80:$SECONDARY_DNS_IP" \
            "$SECONDARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
            -H "Authorization: ServiceAccount $BEARER_TOKEN")
    fi
else
    GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
        "$SECONDARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN")
fi

GET_STATUS=$(echo "$GET_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
GET_DATA=$(echo "$GET_RESPONSE" | grep -v "HTTP_STATUS:")

if [ "$GET_STATUS" = "200" ]; then
    echo "✅ GET from secondary region successful"
    echo "📄 Retrieved data: $GET_DATA"
else
    echo "❌ GET from secondary region failed (HTTP $GET_STATUS)"
    echo "$GET_RESPONSE"
    exit 1
fi

echo ""
echo "🔍 Step 4: Verify data integrity..."
if [ "$GET_DATA" = "$TEST_DATA" ]; then
    echo "✅ Data matches! Cross-region replication working correctly"
    echo "   Original: $TEST_DATA"
    echo "   Retrieved: $GET_DATA"
else
    echo "❌ Data mismatch! Cross-region replication failed"
    echo "   Expected: $TEST_DATA"
    echo "   Got: $GET_DATA"
    exit 1
fi

echo ""
echo "🎉 MULTI-REGION REPLICATION TEST PASSED!"
echo "======================================="
echo "   ✅ Primary region ($PRIMARY_REGION): Working"
echo "   ✅ Secondary region ($SECONDARY_REGION): Working"
echo "   ✅ Cross-region replication: Working"
echo "   ✅ Data integrity: Verified"
echo ""
echo "🚀 Your multi-region DDC deployment is ready for global teams!"
echo "   🔗 Primary: $PRIMARY_ENDPOINT"
echo "   🔗 Secondary: $SECONDARY_ENDPOINT"
echo "   🔑 Shared bearer token for both regions"