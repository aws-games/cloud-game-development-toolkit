#!/bin/bash

# DDC Connectivity Test Script
# Tests public connectivity and basic write/read operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DDC_ENDPOINT="${1:-}"
BEARER_TOKEN="${2:-}"

if [ -z "$DDC_ENDPOINT" ] || [ -z "$BEARER_TOKEN" ]; then
    echo -e "${RED}Usage: $0 <ddc-endpoint> <bearer-token>${NC}"
    echo "Example: $0 http://us-east-1.ddc.example.com your-bearer-token"
    echo ""
    echo "To get values from Terraform:"
    echo "  DDC_ENDPOINT=\$(terraform output -raw ddc_connection | jq -r '.endpoint_nlb')"
    echo "  BEARER_TOKEN=\$(aws secretsmanager get-secret-value --secret-id \$(terraform output -raw ddc_connection | jq -r '.bearer_token_secret_arn') --query SecretString --output text)"
    echo "  $0 \$DDC_ENDPOINT \$BEARER_TOKEN"
    exit 1
fi

echo -e "${YELLOW}Testing DDC Connectivity: $DDC_ENDPOINT${NC}"
echo "=========================================="

# Test 1: Health Check (No Auth Required)
echo -e "\n${YELLOW}Test 1: Health Check${NC}"
if curl -s --max-time 10 "$DDC_ENDPOINT/health/live" | grep -q "Healthy"; then
    echo -e "${GREEN}✅ Health check passed${NC}"
else
    echo -e "${RED}❌ Health check failed${NC}"
    exit 1
fi

# Test 2: Ready Check
echo -e "\n${YELLOW}Test 2: Ready Check${NC}"
if curl -s --max-time 10 "$DDC_ENDPOINT/health/ready" | grep -q "Healthy"; then
    echo -e "${GREEN}✅ Ready check passed${NC}"
else
    echo -e "${RED}❌ Ready check failed${NC}"
    exit 1
fi

# Test 3: API Status (Requires Auth)
echo -e "\n${YELLOW}Test 3: API Status${NC}"
STATUS_RESPONSE=$(curl -s --max-time 10 -H "Authorization: Bearer $BEARER_TOKEN" "$DDC_ENDPOINT/api/v1/status" || echo "FAILED")
if [ "$STATUS_RESPONSE" != "FAILED" ] && [ -n "$STATUS_RESPONSE" ]; then
    echo -e "${GREEN}✅ API status accessible${NC}"
    echo "Response: $STATUS_RESPONSE"
else
    echo -e "${RED}❌ API status failed or timed out${NC}"
fi

# Test 4: Write Test Object
echo -e "\n${YELLOW}Test 4: Write Test Object${NC}"
TEST_NAMESPACE="ddc"  # Use standard DDC namespace
TEST_BUCKET="default"
TEST_HASH="00000000000000000000000000000000000000aa"
TEST_DATA="Hello DDC Test $(date +%s)"
TEST_CONTENT_HASH="4878CA0425C739FA427F7EDA20FE845F6B2E46BA"

WRITE_RESPONSE=$(curl -s --max-time 30 -w "%{http_code}" -o /dev/null \
    -X PUT \
    -H "Authorization: Bearer $BEARER_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    -H "X-Jupiter-IoHash: $TEST_CONTENT_HASH" \
    --data "$TEST_DATA" \
    "$DDC_ENDPOINT/api/v1/refs/$TEST_NAMESPACE/$TEST_BUCKET/$TEST_HASH")

if [ "$WRITE_RESPONSE" = "200" ] || [ "$WRITE_RESPONSE" = "201" ]; then
    echo -e "${GREEN}✅ Write test passed (HTTP $WRITE_RESPONSE)${NC}"
    
    # Test 5: Read Test Object
    echo -e "\n${YELLOW}Test 5: Read Test Object${NC}"
    READ_RESPONSE=$(curl -s --max-time 30 \
        -H "Authorization: Bearer $BEARER_TOKEN" \
        "$DDC_ENDPOINT/api/v1/refs/$TEST_NAMESPACE/$TEST_BUCKET/$TEST_HASH.raw")
    
    if echo "$READ_RESPONSE" | grep -q "Hello DDC Test"; then
        echo -e "${GREEN}✅ Read test passed${NC}"
        echo "Retrieved: $READ_RESPONSE"
    else
        echo -e "${RED}❌ Read test failed${NC}"
        echo "Response: $READ_RESPONSE"
    fi
else
    echo -e "${RED}❌ Write test failed (HTTP $WRITE_RESPONSE)${NC}"
fi

# Test 6: Namespace Info (Optional)
echo -e "\n${YELLOW}Test 6: Namespace Info${NC}"
NAMESPACE_INFO=$(curl -s --max-time 10 -H "Authorization: Bearer $BEARER_TOKEN" "$DDC_ENDPOINT/api/v1/refs/$TEST_NAMESPACE" || echo "FAILED")
if [ "$NAMESPACE_INFO" != "FAILED" ] && [ -n "$NAMESPACE_INFO" ]; then
    echo -e "${GREEN}✅ Namespace info accessible${NC}"
    echo "Response: $NAMESPACE_INFO"
else
    echo -e "${YELLOW}⚠️ Namespace info failed (may not be implemented)${NC}"
fi

echo -e "\n${GREEN}=========================================="
echo -e "DDC Connectivity Test Complete${NC}"
echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Configure Unreal Engine to use: $DDC_ENDPOINT"
echo "2. Use bearer token: $BEARER_TOKEN"
echo "3. Test with actual UE project builds"