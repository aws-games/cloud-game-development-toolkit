#!/bin/bash
set -e

echo "[DDC-TEST] Starting DDC functional testing..."

if [ "$ENABLE_FUNCTIONAL_TESTING" != "true" ]; then
    echo "[DDC-TEST] Functional testing disabled, skipping..."
    exit 0
fi

echo "[DDC-TEST] Waiting 30s for DDC service to fully initialize..."
sleep 30

# Use local test script from S3 assets
echo "[DDC-TEST] Running single-region DDC functional test with retry..."
for i in {1..5}; do
    echo "[DDC-TEST] Test attempt $i/5..."
    chmod +x ./assets/scripts/ddc_functional_test.sh
    if ./assets/scripts/ddc_functional_test.sh; then
        echo "[DDC-TEST] SUCCESS: Single-region functional test completed"
        break
    else
        if [ $i -eq 5 ]; then
            echo "[DDC-TEST] ERROR: All 5 test attempts failed"
            exit 1
        else
            echo "[DDC-TEST] Test attempt $i failed, waiting 60s before retry..."
            sleep 60
        fi
    fi
done

# Multi-region test if peer endpoint provided
if [ -n "$PEER_REGION_DDC_ENDPOINT" ]; then
    echo "[DDC-TEST] Running multi-region DDC functional test..."
    ./assets/scripts/ddc_functional_test_multi_region.sh
    echo "[DDC-TEST] SUCCESS: Multi-region functional test completed"
fi

echo "[DDC-TEST] SUCCESS: All functional tests completed"