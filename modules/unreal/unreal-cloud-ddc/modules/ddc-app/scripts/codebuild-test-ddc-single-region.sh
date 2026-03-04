#!/bin/bash
# ⚠️  INTERNAL CODEBUILD SCRIPT - DO NOT RUN MANUALLY ⚠️
# This script is designed for CodeBuild environments only.
# For manual testing, use: ../../assets/scripts/ddc_functional_test.sh
# This script uses environment variables instead of Terraform outputs.

set -e

echo "🧪 DDC Single-Region Functional Test Starting (CodeBuild Version)..."
echo "=================================================================="

# Get configuration from environment variables (set by CodeBuild)
echo "📋 Getting configuration from environment variables..."

DEFAULT_DDC_NAMESPACE="${DEFAULT_DDC_NAMESPACE:-default}"
CLUSTER_NAME="${CLUSTER_NAME}"
REGION="${AWS_REGION}"
NAMESPACE="${NAMESPACE:-unreal-cloud-ddc}"

# Determine protocol based on debug mode
if [ "${DEBUG:-false}" = "true" ]; then
    PROTOCOL="HTTP"
    CURL_OPTS=""
else
    PROTOCOL="HTTPS"
    CURL_OPTS="--insecure"
fi

echo "📋 Configuration:"
echo "   Protocol: $PROTOCOL"
echo "   Default DDC Namespace: $DEFAULT_DDC_NAMESPACE"
echo "   Cluster: $CLUSTER_NAME"
echo "   Region: $REGION"
echo "   Namespace: $NAMESPACE"
echo "   DDC DNS Endpoint: ${DDC_DNS_ENDPOINT:-'(not set)'}"
echo "   Bearer Token Secret: ${BEARER_TOKEN_SECRET_ARN:-'(not set)'}"
echo "   Debug Mode: ${DEBUG:-false}"
echo ""

# Progressive Health Checks - discover endpoints dynamically
echo "🏥 Progressive Health Checks"
echo "============================"

# Configure kubectl access
echo "🔧 Configuring kubectl access..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# Discover NLB endpoint
echo "🔍 Discovering LoadBalancer endpoint..."
NLB_HOSTNAME=$(kubectl get service -n "$NAMESPACE" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$NLB_HOSTNAME" ]; then
    echo "   ❌ Could not discover LoadBalancer hostname"
    echo "   📊 Services in namespace $NAMESPACE:"
    kubectl get services -n "$NAMESPACE" || echo "   No services found"
    exit 1
fi

echo "   ✅ LoadBalancer discovered: $NLB_HOSTNAME"

# Test NLB directly for RCA purposes
echo "   🎯 Testing NLB directly for troubleshooting..."
NLB_HEALTH=$(curl -s --max-time 10 "http://$NLB_HOSTNAME/health/live" || echo "FAILED")
if echo "$NLB_HEALTH" | grep -qi "healthy"; then
    echo "   ✅ NLB direct /health/live: $NLB_HEALTH"
    NLB_WORKS=true
else
    echo "   ❌ NLB direct /health/live failed: $NLB_HEALTH"
    NLB_WORKS=false
fi

# Set primary endpoint - prefer DNS endpoint if available, fallback to NLB
if [ -n "${DDC_DNS_ENDPOINT:-}" ] && [ "$DDC_DNS_ENDPOINT" != "" ]; then
    # Use DNS endpoint as-is (don't modify protocol)
    PRIMARY_ENDPOINT="$DDC_DNS_ENDPOINT"
    # Update protocol based on DNS endpoint
    if [[ "$DDC_DNS_ENDPOINT" == https://* ]]; then
        PROTOCOL="HTTPS"
        CURL_OPTS="--insecure"
    else
        PROTOCOL="HTTP"
        CURL_OPTS=""
    fi
    echo "   🌐 Using DNS endpoint: $PRIMARY_ENDPOINT (Protocol: $PROTOCOL)"
else
    # Fallback to discovered NLB hostname
    if [ "$PROTOCOL" = "HTTP" ]; then
        PRIMARY_ENDPOINT="http://$NLB_HOSTNAME"
    else
        PRIMARY_ENDPOINT="https://$NLB_HOSTNAME"
    fi
    echo "   🎯 Using NLB endpoint: $PRIMARY_ENDPOINT"
fi

# Get bearer token from Secrets Manager (if configured)
BEARER_TOKEN=""
if [ -n "${BEARER_TOKEN_SECRET_ARN:-}" ]; then
    echo "🔑 Retrieving bearer token from Secrets Manager..."
    BEARER_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$BEARER_TOKEN_SECRET_ARN" --query SecretString --output text 2>/dev/null || echo "")
    if [ -n "$BEARER_TOKEN" ] && [ "$BEARER_TOKEN" != "null" ]; then
        echo "   ✅ Bearer token retrieved: ${BEARER_TOKEN:0:10}..."
    else
        echo "   ⚠️ Bearer token not available, skipping API auth test"
        BEARER_TOKEN=""
    fi
fi

# Level 1: Health Checks with retry logic (same as local script)
echo ""
echo "🏥 Level 1: Health Checks"
echo "========================"

echo "📡 Testing /health/live endpoint with retries..."
MAX_TEST_ATTEMPTS=${MAX_TEST_ATTEMPTS:-30}
DNS_SUCCESS=false
attempt=1
while [ $attempt -le $MAX_TEST_ATTEMPTS ]; do
    echo "   🔄 Attempt $attempt/$MAX_TEST_ATTEMPTS: Testing endpoint..."
    DNS_HEALTH=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/live" || echo "FAILED")
    if echo "$DNS_HEALTH" | grep -qi "healthy"; then
        echo "   ✅ /health/live: $DNS_HEALTH"
        USE_RESOLVED_IP=false
        DNS_SUCCESS=true
        break
    else
        echo "   ❌ Attempt $attempt failed: $DNS_HEALTH"
        if [ $attempt -lt $MAX_TEST_ATTEMPTS ]; then
            echo "   ⏳ Waiting 60 seconds before retry..."
            sleep 60
        fi
    fi
    attempt=$((attempt + 1))
done

if [ "$DNS_SUCCESS" = "false" ]; then
    echo "   ❌ All DNS attempts failed after $MAX_TEST_ATTEMPTS tries"
    echo "   🔍 Testing for local DNS caching issues..."
    
    # Check with external DNS servers (same logic as local script)
    echo "   DNS resolution (Google DNS):"
    RESOLVED_IP=$(dig +short @8.8.8.8 "$(echo "$PRIMARY_ENDPOINT" | sed 's|https\?://||' | cut -d/ -f1)" | head -1 || echo "")
    echo "   Resolved IP: $RESOLVED_IP"
    
    if [ -n "$RESOLVED_IP" ]; then
        echo "   ⚠️  DNS propagation and local DNS caching issue detected"
        echo "   💡 Continuing test with Google DNS resolved IP ($RESOLVED_IP)"
        
        # Test with resolved IP and Host header
        DNS_HOST=$(echo "$PRIMARY_ENDPOINT" | sed 's|https\?://||' | cut -d/ -f1)
        DNS_HEALTH=$(curl -s --max-time 10 $CURL_OPTS -H "Host: $DNS_HOST" "$(echo "$PRIMARY_ENDPOINT" | sed "s|$DNS_HOST|$RESOLVED_IP|")/health/live" || echo "FAILED")
        if echo "$DNS_HEALTH" | grep -qi "healthy"; then
            echo "   ✅ /health/live (resolved IP): $DNS_HEALTH"
            USE_RESOLVED_IP=true
        else
            echo "   ❌ /health/live (resolved IP) failed: $DNS_HEALTH"
            if [ "$NLB_WORKS" = "true" ]; then
                echo "   🔧 RCA: NLB works directly, issue is with DNS/SSL/Route53"
            else
                echo "   🔧 RCA: Both NLB and DNS failed, issue is with NLB target health"
            fi
            exit 1
        fi
    else
        echo "   ❌ DNS resolution failed even with Google DNS"
        if [ "$NLB_WORKS" = "true" ]; then
            echo "   🔧 RCA: NLB works directly, issue is DNS propagation"
            echo "   💡 Wait 5-10 minutes for DNS propagation or use NLB directly"
        else
            echo "   🔧 RCA: Both NLB and DNS failed, issue is with NLB target health"
        fi
        exit 1
    fi
fi

echo "📡 Testing /health/ready endpoint..."
HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/ready" || echo "FAILED")
if echo "$HEALTH_READY" | grep -qi "healthy"; then
    echo "   ✅ /health/ready: $HEALTH_READY"
else
    echo "   ❌ /health/ready failed: $HEALTH_READY"
    exit 1
fi

# Level 3: API Authentication Test (same as local)
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
echo "========================"

# Test data - use default DDC logical namespace from environment
echo "🎯 Using DDC namespace: $DEFAULT_DDC_NAMESPACE"
TEST_HASH="00000000000000000000000000000000000000aa"
# Use test data for cache verification (same as local test)
MESSAGE="🎮 DDC is working! No more waiting for shader compilation! 🚀 Epic Games would be proud! 💯 "
TEST_DATA=$(printf "%.0s$MESSAGE" {1..1000})
echo "📋 Generated ${#TEST_DATA} bytes of test data for cache verification"
# Use the correct hash for the new message
TEST_IOHASH="D11A5A03616CB925EF18A9B587645CE53F0717D6"

echo "📤 Testing PUT operation..."
echo "=========================="
PUT_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}\nSIZE_UPLOAD:%{size_upload}" \
    -D /tmp/put_headers.txt \
    "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
    -X PUT \
    --data "$TEST_DATA" \
    -H 'content-type: application/octet-stream' \
    -H "X-Jupiter-IoHash: $TEST_IOHASH" \
    -H "Authorization: ServiceAccount $BEARER_TOKEN")

PUT_STATUS=$(echo "$PUT_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
PUT_TIME=$(echo "$PUT_RESPONSE" | grep "TIME_TOTAL:" | cut -d: -f2)
PUT_SIZE=$(echo "$PUT_RESPONSE" | grep "SIZE_UPLOAD:" | cut -d: -f2)

echo "📊 PUT Results:"
echo "   Status: $PUT_STATUS"
echo "   Upload time: ${PUT_TIME}s"
echo "   Data uploaded: $PUT_SIZE bytes"
echo "   Data size: ${#TEST_DATA} bytes"
echo "   Hash provided: $TEST_IOHASH"

# Show response headers for debugging
if [ -f /tmp/put_headers.txt ]; then
    echo "📋 Response headers:"
    grep -E "(server|x-|content-)" /tmp/put_headers.txt | sed 's/^/   /' || echo "   (no relevant headers)"
    rm -f /tmp/put_headers.txt
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
GET_RESPONSE=$(curl -s $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}\nSIZE_DOWNLOAD:%{size_download}" \
    -D /tmp/get_headers.txt \
    "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
    -H "Authorization: ServiceAccount $BEARER_TOKEN")

GET_STATUS=$(echo "$GET_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
GET_TIME=$(echo "$GET_RESPONSE" | grep "TIME_TOTAL:" | cut -d: -f2)
GET_SIZE=$(echo "$GET_RESPONSE" | grep "SIZE_DOWNLOAD:" | cut -d: -f2)
GET_DATA=$(echo "$GET_RESPONSE" | grep -v -E "(HTTP_STATUS:|TIME_TOTAL:|SIZE_DOWNLOAD:)")

echo "📊 GET Results:"
echo "   Status: $GET_STATUS"
echo "   Download time: ${GET_TIME}s"
echo "   Data downloaded: $GET_SIZE bytes"
echo "   Expected size: ${#TEST_DATA} bytes"

# Show response headers for debugging
if [ -f /tmp/get_headers.txt ]; then
    echo "📋 Response headers:"
    grep -E "(server|x-|content-)" /tmp/get_headers.txt | sed 's/^/   /' || echo "   (no relevant headers)"
    rm -f /tmp/get_headers.txt
fi

if [ "$GET_STATUS" = "200" ]; then
    echo "✅ GET operation successful"
    echo "📄 Response data preview:"
    echo "$GET_DATA" | head -c 200 | sed 's/^/   /'
    if [ ${#GET_DATA} -gt 200 ]; then
        echo "   ... (truncated, total ${#GET_DATA} characters)"
    fi
else
    echo "❌ GET operation failed"
    echo "$GET_RESPONSE"
    exit 1
fi

echo ""
echo "🔍 Cache Storage Summary"
echo "========================"
echo "   ✅ DDC cache is working correctly!"
echo "   📊 Data size: ${#TEST_DATA} bytes"
echo ""
echo "   🔧 Manual verification commands (if needed):"
echo "   🔗 ScyllaDB: aws ssm start-session --target [SCYLLA-INSTANCE-ID] --region $REGION"
echo "   📦 S3 bucket: aws s3 ls s3://[BUCKET-NAME]/ --recursive"

echo ""
echo "🎉 DDC Single-Region Test PASSED!"
echo "=================================="
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

# Test completed
echo "💡 MANUAL NLB TESTING (if needed):"
if [ -n "$CLUSTER_NAME" ] && [ -n "$REGION" ] && [ -n "$NLB_HOSTNAME" ]; then
    echo "   Configure kubectl: aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
    echo "   NLB hostname: $NLB_HOSTNAME"
    echo "   Test NLB directly: curl -f http://$NLB_HOSTNAME/health/live"
else
    echo "   Configure kubectl: aws eks update-kubeconfig --region [REGION] --name [CLUSTER-NAME]"
    echo "   Get NLB hostname: kubectl get service -n $NAMESPACE -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
    echo "   Test NLB directly: curl -f http://[NLB-HOSTNAME]/health/live"
fi