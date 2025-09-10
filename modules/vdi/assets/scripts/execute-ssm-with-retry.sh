#!/bin/bash
# Execute SSM command with retries for race condition handling

DOCUMENT_NAME=$1
INSTANCE_ID=$2
WORKSTATION_KEY=$3
ASSIGNED_USER=$4
PROJECT_PREFIX=$5

MAX_RETRIES=10
RETRY_DELAY=30

for ((i=1; i<=MAX_RETRIES; i++)); do
  echo "Attempt $i: Sending SSM command to instance $INSTANCE_ID"
  
  COMMAND_ID=$(aws ssm send-command \
    --document-name "$DOCUMENT_NAME" \
    --instance-ids "$INSTANCE_ID" \
    --parameters "WorkstationKey=$WORKSTATION_KEY,AssignedUser=$ASSIGNED_USER,UserSource=local,ProjectPrefix=$PROJECT_PREFIX" \
    --comment "Immediate user creation for $WORKSTATION_KEY" \
    --query "Command.CommandId" \
    --output text 2>/dev/null)

  if [ $? -eq 0 ] && [ "$COMMAND_ID" != "None" ]; then
    echo "SSM command sent successfully. CommandId: $COMMAND_ID"
    exit 0
  else
    echo "Failed to send SSM command. Retrying in $RETRY_DELAY seconds..."
    sleep "$RETRY_DELAY"
  fi
done

echo "Failed to send SSM command after $MAX_RETRIES attempts."
exit 1