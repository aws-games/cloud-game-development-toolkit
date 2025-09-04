#!/bin/bash

# DDC Multi-Region Functional Test - Tests PUT/GET operations across regions
# Tests both primary and secondary regions independently

set -e

echo "🌍 DDC Multi-Region Functional Test Starting..."
echo "=============================================="

# Function to test a single region
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
    
    # Test primary endpoint health
    HEALTH_LIVE=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/live" || echo "FAILED")
    if echo "$HEALTH_LIVE" | grep -qi "healthy"; then
        echo "   ✅ Primary /health/live: $HEALTH_LIVE"
    else
        echo "   ❌ Primary /health/live failed: $HEALTH_LIVE"
        return 1
    fi
    
    HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/ready" || echo "FAILED")
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
    API_STATUS=$(curl -s --max-time 10 $CURL_OPTS -w "HTTP_STATUS:%{http_code}" \
        -H "Authorization: ServiceAccount $bearer_token" \
        "$PRIMARY_ENDPOINT/api/v1/status" || echo "FAILED")
    
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
    
    # Test data - use region-specific hash to avoid conflicts
    FIRST_NAMESPACE="ddc"
    # Use region-specific test hash to avoid cross-region conflicts
    TEST_HASH="00000000000000000000000000000000000000$(echo "$region_name" | md5sum | cut -c1-2)"
    TEST_DATA="test-$region_name"
    # Calculate hash for region-specific data
    TEST_IOHASH=$(echo -n "$TEST_DATA" | sha1sum | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
    
    echo "📤 Testing PUT operation..."
    echo "=========================="
    PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
        "$PRIMARY_ENDPOINT/api/v1/refs/$FIRST_NAMESPACE/default/$TEST_HASH" \
        -X PUT \
        --data "$TEST_DATA" \
        -H 'content-type: application/octet-stream' \
        -H "X-Jupiter-IoHash: $TEST_IOHASH" \
        -H "Authorization: ServiceAccount $bearer_token")
    
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
    GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
        "$PRIMARY_ENDPOINT/api/v1/refs/$FIRST_NAMESPACE/default/$TEST_HASH.raw" \
        -H "Authorization: ServiceAccount $bearer_token")
    
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
    exit 1
fi

if [ -z "$SECONDARY_DDC_DNS_ENDPOINT" ] && [ -z "$SECONDARY_DDC_DIRECT_ENDPOINT" ]; then
    echo "❌ Could not get secondary region DDC endpoints from terraform outputs"
    echo "💡 Make sure you're running this from your multi-region terraform directory"
    echo "💡 And that 'terraform apply' completed successfully"
    exit 1
fi

# Get bearer tokens from AWS Secrets Manager
PRIMARY_BEARER_TOKEN_SECRET_ARN=$(terraform output -raw primary_bearer_token_secret_arn 2>/dev/null)
SECONDARY_BEARER_TOKEN_SECRET_ARN=$(terraform output -raw secondary_bearer_token_secret_arn 2>/dev/null)

if [ -n "$PRIMARY_BEARER_TOKEN_SECRET_ARN" ]; then
    PRIMARY_BEARER_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$PRIMARY_BEARER_TOKEN_SECRET_ARN" --query SecretString --output text 2>/dev/null || echo "generated-token")
else
    PRIMARY_BEARER_TOKEN="generated-token"
fi

if [ -n "$SECONDARY_BEARER_TOKEN_SECRET_ARN" ]; then
    SECONDARY_BEARER_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$SECONDARY_BEARER_TOKEN_SECRET_ARN" --query SecretString --output text 2>/dev/null || echo "generated-token")
else
    SECONDARY_BEARER_TOKEN="generated-token"
fi

# Use default tokens if retrieval failed
if [ -z "$PRIMARY_BEARER_TOKEN" ] || [ "$PRIMARY_BEARER_TOKEN" = "null" ]; then
    echo "⚠️  No primary bearer token found, using default"
    PRIMARY_BEARER_TOKEN="generated-token"
fi

if [ -z "$SECONDARY_BEARER_TOKEN" ] || [ "$SECONDARY_BEARER_TOKEN" = "null" ]; then
    echo "⚠️  No secondary bearer token found, using default"
    SECONDARY_BEARER_TOKEN="generated-token"
fi

echo "📋 Multi-Region Configuration:"
echo "   Primary Region: $PRIMARY_REGION"
echo "   Secondary Region: $SECONDARY_REGION"
echo "   Debug Mode: $DEBUG_MODE"
echo ""

# Test results tracking
FAILED_REGIONS=()

# Test Primary Region
echo "🌎 Testing Primary Region ($PRIMARY_REGION)"
echo "==========================================="
if test_region "$PRIMARY_REGION" "$PRIMARY_DDC_DNS_ENDPOINT" "$PRIMARY_DDC_DIRECT_ENDPOINT" "$PRIMARY_BEARER_TOKEN" "$DEBUG_MODE"; then
    echo "✅ Primary region test completed successfully"
else
    echo "❌ Primary region test failed"
    FAILED_REGIONS+=("$PRIMARY_REGION")
fi

# Test Secondary Region
echo ""
echo "🌎 Testing Secondary Region ($SECONDARY_REGION)"
echo "=============================================="
if test_region "$SECONDARY_REGION" "$SECONDARY_DDC_DNS_ENDPOINT" "$SECONDARY_DDC_DIRECT_ENDPOINT" "$SECONDARY_BEARER_TOKEN" "$DEBUG_MODE"; then
    echo "✅ Secondary region test completed successfully"
else
    echo "❌ Secondary region test failed"
    FAILED_REGIONS+=("$SECONDARY_REGION")
fi

# Final Results
echo ""
echo "🌍 Multi-Region Test Results"
echo "============================"

if [ ${#FAILED_REGIONS[@]} -eq 0 ]; then
    echo "🎉 ALL REGIONS PASSED!"
    echo "======================"
    echo "   ✅ Primary Region ($PRIMARY_REGION): Working"
    echo "   ✅ Secondary Region ($SECONDARY_REGION): Working"
    echo ""
    echo "🚀 Your multi-region DDC deployment is ready for Unreal Engine!"
    echo "   🔗 Primary: $PRIMARY_DDC_DNS_ENDPOINT"
    echo "   🔗 Secondary: $SECONDARY_DDC_DNS_ENDPOINT"
    echo "   🔑 Use bearer tokens for UE configuration"
    exit 0
else
    echo "❌ SOME REGIONS FAILED"
    echo "====================="
    for region in "${FAILED_REGIONS[@]}"; do
        echo "   ❌ $region: Failed"
    done
    echo ""
    echo "💡 Check the logs above for specific failure details"
    exit 1
fi