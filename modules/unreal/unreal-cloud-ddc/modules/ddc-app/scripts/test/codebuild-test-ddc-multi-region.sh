#!/bin/bash
# ⚠️  INTERNAL CODEBUILD SCRIPT - DO NOT RUN MANUALLY ⚠️
# This script is designed for CodeBuild environments only.
# For manual testing, use: ../../assets/scripts/ddc_functional_test_multi_region.sh
# This script uses environment variables instead of Terraform outputs.

set -e

echo "🌍 DDC Multi-Region Functional Test Starting (CodeBuild Version)..."
echo "=================================================================="
echo "📋 This test validates DDC cross-region replication:"
echo "   1. PUT data to primary region"
echo "   2. Wait for DDC replication (via ScyllaDB)"
echo "   3. GET data from secondary region"
echo "   4. Verify data matches"
echo ""

# Get configuration from environment variables
echo "📋 Getting configuration from environment variables..."

# Primary region configuration
PRIMARY_ENDPOINT="${PRIMARY_DDC_ENDPOINT:-}"
PRIMARY_REGION="${PRIMARY_REGION:-primary}"

# Secondary region configuration
SECONDARY_ENDPOINT="${SECONDARY_DDC_ENDPOINT:-}"
SECONDARY_REGION="${SECONDARY_REGION:-secondary}"

# Other configuration
BEARER_TOKEN="${BEARER_TOKEN:-generated-token}"
DEFAULT_DDC_NAMESPACE="${DEFAULT_DDC_NAMESPACE:-default}"
DEBUG_MODE="${DEBUG_MODE:-disabled}"

# Validation
if [[ -z "$PRIMARY_ENDPOINT" || -z "$SECONDARY_ENDPOINT" ]]; then
    echo "❌ ERROR: PRIMARY_DDC_ENDPOINT and SECONDARY_DDC_ENDPOINT environment variables required"
    echo "   Set by CodeBuild environment configuration"
    exit 1
fi

# Determine protocol and curl options
if [[ "$DEBUG_MODE" == "enabled" ]]; then
    PROTOCOL="HTTP"
    PRIMARY_ENDPOINT=$(echo "$PRIMARY_ENDPOINT" | sed 's/^https:/http:/')
    SECONDARY_ENDPOINT=$(echo "$SECONDARY_ENDPOINT" | sed 's/^https:/http:/')
    CURL_OPTS=""
else
    PROTOCOL="HTTPS"
    CURL_OPTS="--insecure"
fi

echo "📋 Multi-Region Configuration:"
echo "   Primary Region: $PRIMARY_REGION ($PRIMARY_ENDPOINT)"
echo "   Secondary Region: $SECONDARY_REGION ($SECONDARY_ENDPOINT)"
echo "   Protocol: $PROTOCOL (Debug: $DEBUG_MODE)"
echo "   DDC Namespace: $DEFAULT_DDC_NAMESPACE"
echo "   ✅ Bearer token: ${BEARER_TOKEN:0:10}..."
echo ""

# Function to test endpoint health with retries and DNS fallback (same as local script)
test_endpoint_health() {
    local endpoint="$1"
    local region_name="$2"
    
    echo "🏥 Testing $region_name endpoint health..."
    
    # Try endpoint with retries first
    local success=false
    local max_attempts=5
    for attempt in $(seq 1 $max_attempts); do
        echo "   🔄 Attempt $attempt/$max_attempts: Testing endpoint..."
        HEALTH_LIVE=$(curl -s --max-time 10 $CURL_OPTS "$endpoint/health/live" || echo "FAILED")
        if echo "$HEALTH_LIVE" | grep -qi "healthy"; then
            echo "   ✅ $region_name /health/live: $HEALTH_LIVE"
            USE_RESOLVED_IP=false
            success=true
            break
        else
            echo "   ❌ Attempt $attempt failed: $HEALTH_LIVE"
            if [ $attempt -lt $max_attempts ]; then
                echo "   ⏳ Waiting 10 seconds before retry..."
                sleep 10
            fi
        fi
    done
    
    if [ "$success" = "false" ]; then
        echo "   ❌ All attempts failed after $max_attempts tries"
        echo "   🔍 Testing for DNS caching issues..."
        
        # Extract hostname for DNS resolution
        ENDPOINT_HOST=$(echo "$endpoint" | sed 's|https://||' | sed 's|http://||' | cut -d: -f1)
        echo "   DNS resolution (Google DNS):"
        RESOLVED_IP=$(dig +short @8.8.8.8 "$ENDPOINT_HOST" | head -1 || echo "")
        echo "   Resolved IP: $RESOLVED_IP"
        
        if [ -n "$RESOLVED_IP" ]; then
            echo "   ⚠️  DNS propagation and local DNS caching issue detected"
            echo "   💡 Trying with Google DNS resolved IP ($RESOLVED_IP)"
            
            # Test with resolved IP and Host header
            DNS_HEALTH=$(curl -s --max-time 10 $CURL_OPTS -H "Host: $ENDPOINT_HOST" "$(echo "$endpoint" | sed "s|$ENDPOINT_HOST|$RESOLVED_IP|")/health/live" || echo "FAILED")
            if echo "$DNS_HEALTH" | grep -qi "healthy"; then
                echo "   ✅ $region_name /health/live (resolved IP): $DNS_HEALTH"
                USE_RESOLVED_IP=true
                RESOLVED_ENDPOINT="$(echo "$endpoint" | sed "s|$ENDPOINT_HOST|$RESOLVED_IP|")"
            else
                echo "   ❌ Health check failed even with resolved IP: $DNS_HEALTH"
                return 1
            fi
        else
            echo "   ❌ DNS resolution failed even with Google DNS"
            return 1
        fi
    fi
    
    # Test readiness endpoint with conditional logic
    if [ "$USE_RESOLVED_IP" = "true" ]; then
        HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS -H "Host: $ENDPOINT_HOST" "$RESOLVED_ENDPOINT/health/ready" || echo "FAILED")
    else
        HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS "$endpoint/health/ready" || echo "FAILED")
    fi
    if echo "$HEALTH_READY" | grep -qi "healthy"; then
        echo "   ✅ $region_name /health/ready: $HEALTH_READY"
    else
        echo "   ❌ $region_name /health/ready failed: $HEALTH_READY"
        return 1
    fi
    
    return 0
}

# Test endpoint health first
echo "🏥 Health Check Phase"
echo "===================="
if ! test_endpoint_health "$PRIMARY_ENDPOINT" "$PRIMARY_REGION"; then
    echo "❌ Primary region health check failed"
    exit 1
fi

if ! test_endpoint_health "$SECONDARY_ENDPOINT" "$SECONDARY_REGION"; then
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
# Get DNS info for primary endpoint (using Google DNS)
PRIMARY_DNS_HOST=$(echo "$PRIMARY_ENDPOINT" | sed 's|https://||' | sed 's|http://||')
PRIMARY_DNS_IP=$(dig @8.8.8.8 +short "$PRIMARY_DNS_HOST" | head -1)

if [ -n "$PRIMARY_DNS_IP" ] && [[ "$PRIMARY_ENDPOINT" == *"$PRIMARY_DNS_HOST"* ]]; then
    PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
        -H "Host: $PRIMARY_DNS_HOST" \
        "$(echo "$PRIMARY_ENDPOINT" | sed "s|$PRIMARY_DNS_HOST|$PRIMARY_DNS_IP|")/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
        -X PUT \
        --data "$TEST_DATA" \
        -H 'content-type: application/octet-stream' \
        -H "X-Jupiter-IoHash: $TEST_IOHASH" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN")
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
if [[ "$PUT_STATUS" == "200" || "$PUT_STATUS" == "201" ]]; then
    echo "✅ PUT to primary region successful"
else
    echo "❌ PUT to primary region failed (HTTP $PUT_STATUS)"
    echo "$PUT_RESPONSE"
    exit 1
fi

echo ""
echo "⏳ Step 2: Waiting for ScyllaDB cross-region replication..."
echo "   ℹ️  Waiting 60 seconds for data to replicate to secondary region"
wait_seconds=60
for i in $(seq 1 $wait_seconds); do
    echo -n "."
    sleep 1
    if [[ $((i % 10)) -eq 0 ]]; then
        echo " ${i}s"
    fi
done
echo ""
echo "✅ Replication wait complete"

echo ""
echo "📥 Step 3: GET data from secondary region ($SECONDARY_REGION)..."
# Get DNS info for secondary endpoint (using Google DNS)
SECONDARY_DNS_HOST=$(echo "$SECONDARY_ENDPOINT" | sed 's|https://||' | sed 's|http://||')
SECONDARY_DNS_IP=$(dig @8.8.8.8 +short "$SECONDARY_DNS_HOST" | head -1)

if [ -n "$SECONDARY_DNS_IP" ] && [[ "$SECONDARY_ENDPOINT" == *"$SECONDARY_DNS_HOST"* ]]; then
    GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
        -H "Host: $SECONDARY_DNS_HOST" \
        "$(echo "$SECONDARY_ENDPOINT" | sed "s|$SECONDARY_DNS_HOST|$SECONDARY_DNS_IP|")/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN")
else
    GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
        "$SECONDARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN")
fi

GET_STATUS=$(echo "$GET_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
GET_DATA=$(echo "$GET_RESPONSE" | grep -v "HTTP_STATUS:")

if [[ "$GET_STATUS" == "200" ]]; then
    echo "✅ GET from secondary region successful"
    echo "📄 Retrieved data: $GET_DATA"
else
    echo "❌ GET from secondary region failed (HTTP $GET_STATUS)"
    echo "$GET_RESPONSE"
    exit 1
fi

echo ""
echo "🔍 Step 4: Verify data integrity..."
if [[ "$GET_DATA" == "$TEST_DATA" ]]; then
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

# Show DNS caching notice if fallback was used
if [ "$USE_RESOLVED_IP" = "true" ]; then
    echo ""
    echo "⚠️  DNS CACHING ISSUE DETECTED:"
    echo "   🔍 Issue: DNS cache has stale records"
    echo "   🕰️ Cause: DNS propagation delay after infrastructure updates"
    echo "   🛠️ Solutions:"
    echo "     1. Wait 5-10 minutes for DNS propagation to complete globally"
    echo "     2. This is normal in CI/CD environments after infrastructure changes"
    echo "   📝 Note: This test used Google DNS to bypass the cache"
fi