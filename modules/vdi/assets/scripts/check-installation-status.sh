#!/bin/bash
# Check installation status for all workstations

INSTANCE_ID=$1
WORKSTATION_KEY=$2

echo "Checking installation status for $WORKSTATION_KEY ($INSTANCE_ID)..."

# Get recent command executions
COMMANDS=$(aws ssm describe-instance-information --instance-information-filter-list key=InstanceIds,valueSet=$INSTANCE_ID --query 'InstanceInformationList[0].PingStatus' --output text)

if [ "$COMMANDS" = "Online" ]; then
    echo "✅ SSM Agent: Online"
    
    # Check recent command executions
    aws ssm list-command-invocations \
        --instance-id $INSTANCE_ID \
        --query 'CommandInvocations[?starts_with(Comment, `Immediate`) || contains(DocumentName, `chocolatey`) || contains(DocumentName, `git`) || contains(DocumentName, `unreal`)].{Status:Status,Document:DocumentName,Comment:Comment,StartTime:RequestedDateTime}' \
        --output table
else
    echo "❌ SSM Agent: Offline"
fi