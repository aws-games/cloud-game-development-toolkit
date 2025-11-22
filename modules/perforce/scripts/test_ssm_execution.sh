#!/bin/bash
# TODO: Remove this test script after SSM functionality is verified
# Simple test script to verify SSM execution

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TEST_FILE="/var/log/ssm_test_execution.log"

echo "[$TIMESTAMP] SSM script executed successfully" >> $TEST_FILE
echo "[$TIMESTAMP] Current user: $(whoami)" >> $TEST_FILE
echo "[$TIMESTAMP] Working directory: $(pwd)" >> $TEST_FILE
echo "[$TIMESTAMP] Available disk space:" >> $TEST_FILE
df -h >> $TEST_FILE
echo "[$TIMESTAMP] Test completed" >> $TEST_FILE

# Also create a simple marker file
touch /var/log/ssm_executed_$(date +%s)

echo "SUCCESS: Test script completed. Check /var/log/ssm_test_execution.log"