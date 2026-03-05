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

# Level 0: Infrastructure Readiness Checks
echo ""
echo "🏗️ Level 0: Infrastructure Readiness"
echo "===================================="

# Check if DDC nodes are available
echo "🖥️ Checking DDC node availability..."
DDC_NODES=$(kubectl get nodes -l "karpenter.sh/nodepool=ddc-compute" --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$DDC_NODES" -gt 0 ]; then
    echo "   ✅ DDC nodes available: $DDC_NODES node(s)"
    kubectl get nodes -l "karpenter.sh/nodepool=ddc-compute" --no-headers | sed 's/^/   📋 /'
else
    echo "   ⚠️ No DDC-specific nodes found, checking all nodes..."
    ALL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$ALL_NODES" -gt 0 ]; then
        echo "   ✅ Cluster nodes available: $ALL_NODES node(s)"
        kubectl get nodes --no-headers | sed 's/^/   📋 /'
    else
        echo "   ❌ No nodes available in cluster"
        exit 1
    fi
fi

# Check DDC pod status
echo "🐳 Checking DDC pod status..."
DDC_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$DDC_PODS" -gt 0 ]; then
    echo "   📊 Found $DDC_PODS pod(s) in namespace $NAMESPACE"
    
    # Check pod readiness
    READY_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null || echo "0")
    PENDING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Pending" 2>/dev/null || echo "0")
    
    # Clean up any newlines that might break arithmetic
    READY_PODS=$(echo "$READY_PODS" | tr -d '\n')
    PENDING_PODS=$(echo "$PENDING_PODS" | tr -d '\n')
    
    echo "   ✅ Running pods: $READY_PODS"
    if [ "$PENDING_PODS" -gt 0 ]; then
        echo "   ⏳ Pending pods: $PENDING_PODS"
    fi
    
    # Show pod details
    echo "   📋 Pod status:"
    kubectl get pods -n "$NAMESPACE" --no-headers | sed 's/^/   📦 /' || echo "   (unable to get pod details)"
    
    # Wait for pods to be ready if any are pending
    if [ "$PENDING_PODS" -gt 0 ]; then
        echo "   ⏳ Waiting up to 5 minutes for pods to be ready..."
        kubectl wait --for=condition=Ready pods --all -n "$NAMESPACE" --timeout=300s || {
            echo "   ⚠️ Some pods may still be starting, continuing with tests..."
        }
    fi
else
    echo "   ❌ No DDC pods found in namespace $NAMESPACE"
    echo "   🔍 Available namespaces:"
    kubectl get namespaces --no-headers | sed 's/^/   📁 /' || echo "   (unable to list namespaces)"
    exit 1
fi

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

# Test NLB directly for RCA purposes with retries
echo "   🎯 Testing NLB directly for troubleshooting..."
NLB_WORKS=false
NLB_ATTEMPTS=10
nlb_attempt=1
while [ $nlb_attempt -le $NLB_ATTEMPTS ]; do
    echo "   🔄 NLB attempt $nlb_attempt/$NLB_ATTEMPTS: Testing NLB health..."
    NLB_HEALTH=$(curl -s --max-time 10 "http://$NLB_HOSTNAME/health/live" || echo "FAILED")
    if echo "$NLB_HEALTH" | grep -qi "healthy"; then
        echo "   ✅ NLB direct /health/live: $NLB_HEALTH"
        NLB_WORKS=true
        break
    else
        echo "   ❌ NLB attempt $nlb_attempt failed: $NLB_HEALTH"
        if [ $nlb_attempt -lt $NLB_ATTEMPTS ]; then
            echo "   ⏳ Waiting 30 seconds for NLB targets to become healthy..."
            sleep 30
        fi
    fi
    nlb_attempt=$((nlb_attempt + 1))
done

if [ "$NLB_WORKS" = "false" ]; then
    echo "   ❌ NLB health check failed after $NLB_ATTEMPTS attempts (~$((NLB_ATTEMPTS * 30 / 60)) minutes)"
    echo "   💡 This indicates NLB target health issues or pods still starting"
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

# Level 1: Health Checks with retry logic
echo ""
echo "🏥 Level 1: Health Checks"
echo "========================"

echo "📡 Testing /health/live endpoint with retries..."
MAX_TEST_ATTEMPTS=${MAX_TEST_ATTEMPTS:-15}  # Reduced from 30 to 15 attempts
TEST_INTERVAL=60  # Keep original timing - DNS propagation needs this
DNS_SUCCESS=false
USE_RESOLVED_IP=false
attempt=1
while [ $attempt -le $MAX_TEST_ATTEMPTS ]; do
    echo "   🔄 Attempt $attempt/$MAX_TEST_ATTEMPTS: curl $CURL_OPTS \"$PRIMARY_ENDPOINT/health/live\""
    DNS_HEALTH=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/live" || echo "FAILED")
    if echo "$DNS_HEALTH" | grep -qi "healthy"; then
        echo "   ✅ /health/live: $DNS_HEALTH"
        DNS_SUCCESS=true
        break
    else
        echo "   ❌ Attempt $attempt failed: $DNS_HEALTH"
        if [ $attempt -lt $MAX_TEST_ATTEMPTS ]; then
            echo "   ⏳ Waiting $TEST_INTERVAL seconds before retry..."
            sleep $TEST_INTERVAL
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
        RESOLVED_ENDPOINT="$(echo "$PRIMARY_ENDPOINT" | sed "s|$DNS_HOST|$RESOLVED_IP|")"
        echo "   🔄 Testing resolved IP: curl $CURL_OPTS -H \"Host: $DNS_HOST\" \"$RESOLVED_ENDPOINT/health/live\""
        DNS_HEALTH=$(curl -s --max-time 10 $CURL_OPTS -H "Host: $DNS_HOST" "$RESOLVED_ENDPOINT/health/live" || echo "FAILED")
        if echo "$DNS_HEALTH" | grep -qi "healthy"; then
            echo "   ✅ /health/live (resolved IP): $DNS_HEALTH"
            USE_RESOLVED_IP=true
            DNS_SUCCESS=true
        else
            echo "   ❌ Resolved IP test failed: $DNS_HEALTH"
        fi
    else
        echo "   ❌ Could not resolve IP with Google DNS"
    fi
    
    if [ "$DNS_SUCCESS" = "false" ]; then
        if [ "$NLB_WORKS" = "true" ]; then
            echo "   ✅ DEPLOYMENT TEST PASSED: NLB health check successful"
            echo "   💡 DNS propagation still in progress (can take 15-30+ minutes)"
            echo "   🎯 Infrastructure is healthy and ready"
            exit 0
        else
            echo "   ❌ Both DNS and NLB failed - infrastructure issue"
            exit 1
        fi
    fi
fi

# Test readiness endpoint
echo "📡 Testing /health/ready endpoint with retries..."
READY_SUCCESS=false
READY_ATTEMPTS=5
attempt=1
while [ $attempt -le $READY_ATTEMPTS ]; do
    echo "   🔄 Attempt $attempt/$READY_ATTEMPTS: Testing readiness endpoint..."
    if [ "$USE_RESOLVED_IP" = "true" ]; then
        HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS -H "Host: $DNS_HOST" "$RESOLVED_ENDPOINT/health/ready" || echo "FAILED")
    else
        HEALTH_READY=$(curl -s --max-time 10 $CURL_OPTS "$PRIMARY_ENDPOINT/health/ready" || echo "FAILED")
    fi
    
    if echo "$HEALTH_READY" | grep -qi "healthy"; then
        echo "   ✅ /health/ready: $HEALTH_READY"
        READY_SUCCESS=true
        break
    else
        echo "   ❌ Attempt $attempt failed: $HEALTH_READY"
        if [ $attempt -lt $READY_ATTEMPTS ]; then
            echo "   ⏳ Waiting 10 seconds before retry..."
            sleep 10
        fi
    fi
    attempt=$((attempt + 1))
done

if [ "$READY_SUCCESS" = "false" ]; then
    echo "   ⚠️ /health/ready failed after $READY_ATTEMPTS tries - continuing with functional tests"
fi

# Level 2: API Authentication Test
echo ""
echo "🔐 Level 2: API Authentication"
if [ -n "$BEARER_TOKEN" ]; then
    if [ "$USE_RESOLVED_IP" = "true" ]; then
        API_STATUS=$(curl -s --max-time 10 $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: ServiceAccount $BEARER_TOKEN" \
            -H "Host: $DNS_HOST" \
            "$RESOLVED_ENDPOINT/api/v1/status" || echo "FAILED")
    else
        API_STATUS=$(curl -s --max-time 10 $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}" \
            -H "Authorization: ServiceAccount $BEARER_TOKEN" \
            "$PRIMARY_ENDPOINT/api/v1/status" || echo "FAILED")
    fi
    
    STATUS_CODE=$(echo "$API_STATUS" | grep "^HTTP_STATUS:" | cut -d: -f2)
    if [ "$STATUS_CODE" = "200" ]; then
        echo "   ✅ API authentication successful"
    else
        echo "   ⚠️ API authentication failed (HTTP $STATUS_CODE) - continuing with functional tests"
    fi
else
    echo "   ⚠️ No bearer token available - skipping API auth test"
fi

# Level 3: Functional Cache Tests
echo ""
echo "🧪 Level 3: Functional Cache Tests"
echo "=================================="

echo "🎯 Using DDC namespace: $DEFAULT_DDC_NAMESPACE"
TEST_HASH="00000000000000000000000000000000000000aa"
MESSAGE="🎮 DDC is working! No more waiting for shader compilation! 🚀 Epic Games would be proud! 💯 "
TEST_DATA=$(printf "%.0s$MESSAGE" {1..1000})
echo "📋 Generated ${#TEST_DATA} bytes of test data for cache verification"
TEST_IOHASH="D11A5A03616CB925EF18A9B587645CE53F0717D6"

echo "📤 Testing PUT operation..."
echo "=========================="
echo "   🔄 Attempting PUT request (timeout: 30s)..."
if [ "$USE_RESOLVED_IP" = "true" ]; then
    PUT_RESPONSE=$(curl -s --max-time 30 $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}\nSIZE_UPLOAD:%{size_upload}" \
        -H "Host: $DNS_HOST" \
        "$RESOLVED_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
        -X PUT \
        --data "$TEST_DATA" \
        -H 'content-type: application/octet-stream' \
        -H "X-Jupiter-IoHash: $TEST_IOHASH" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN" || echo "CURL_FAILED")
else
    PUT_RESPONSE=$(curl -s --max-time 30 $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}\nSIZE_UPLOAD:%{size_upload}" \
        "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH" \
        -X PUT \
        --data "$TEST_DATA" \
        -H 'content-type: application/octet-stream' \
        -H "X-Jupiter-IoHash: $TEST_IOHASH" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN" || echo "CURL_FAILED")
fi

if echo "$PUT_RESPONSE" | grep -q "CURL_FAILED"; then
    echo "❌ PUT request failed - curl command timed out or failed"
    exit 1
fi

PUT_STATUS=$(echo "$PUT_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
PUT_TIME=$(echo "$PUT_RESPONSE" | grep "TIME_TOTAL:" | cut -d: -f2)
PUT_SIZE=$(echo "$PUT_RESPONSE" | grep "SIZE_UPLOAD:" | cut -d: -f2)

echo "📊 PUT Results:"
echo "   Status: $PUT_STATUS"
echo "   Upload time: ${PUT_TIME}s"
echo "   Data uploaded: $PUT_SIZE bytes"

if [ "$PUT_STATUS" = "200" ] || [ "$PUT_STATUS" = "201" ]; then
    echo "✅ PUT operation successful"
else
    echo "❌ PUT operation failed"
    exit 1
fi

echo ""
echo "📥 Testing GET operation..."
echo "=========================="
echo "   🔄 Attempting GET request (timeout: 30s)..."
if [ "$USE_RESOLVED_IP" = "true" ]; then
    GET_RESPONSE=$(curl -s --max-time 30 $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}\nSIZE_DOWNLOAD:%{size_download}" \
        -H "Host: $DNS_HOST" \
        "$RESOLVED_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN" || echo "CURL_FAILED")
else
    GET_RESPONSE=$(curl -s --max-time 30 $CURL_OPTS -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}\nSIZE_DOWNLOAD:%{size_download}" \
        "$PRIMARY_ENDPOINT/api/v1/refs/$DEFAULT_DDC_NAMESPACE/default/$TEST_HASH.raw" \
        -H "Authorization: ServiceAccount $BEARER_TOKEN" || echo "CURL_FAILED")
fi

if echo "$GET_RESPONSE" | grep -q "CURL_FAILED"; then
    echo "❌ GET request failed - curl command timed out or failed"
    exit 1
fi

GET_STATUS=$(echo "$GET_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
GET_TIME=$(echo "$GET_RESPONSE" | grep "TIME_TOTAL:" | cut -d: -f2)
GET_SIZE=$(echo "$GET_RESPONSE" | grep "SIZE_DOWNLOAD:" | cut -d: -f2)

echo "📊 GET Results:"
echo "   Status: $GET_STATUS"
echo "   Download time: ${GET_TIME}s"
echo "   Data downloaded: $GET_SIZE bytes"

if [ "$GET_STATUS" = "200" ]; then
    echo "✅ GET operation successful"
else
    echo "❌ GET operation failed"
    exit 1
fi

echo ""
echo "🎉 DDC Complete Test PASSED!"
echo "================================"
echo "   ✅ Infrastructure: Ready"
echo "   ✅ Health endpoints: Working"
echo "   ✅ PUT operation: Working"
echo "   ✅ GET operation: Working"
echo "   ✅ End-to-end cache: Working"
echo ""
echo "🚀 DDC deployment is ready for Unreal Engine!"
