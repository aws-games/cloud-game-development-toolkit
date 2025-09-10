#!/bin/bash
# Execute software installation SSM command with retries

DOCUMENT_NAME=$1
INSTANCE_ID=$2
WORKSTATION_KEY=$3

MAX_RETRIES=10
RETRY_DELAY=30

for ((i=1; i<=MAX_RETRIES; i++)); do
  echo "Attempt $i: Installing software on instance $INSTANCE_ID"
  
  COMMAND_ID=$(aws ssm send-command \
    --document-name "$DOCUMENT_NAME" \
    --instance-ids "$INSTANCE_ID" \
    --comment "Immediate software installation for $WORKSTATION_KEY" \
    --query "Command.CommandId" \
    --output text 2>/dev/null)

  if [ $? -eq 0 ] && [ "$COMMAND_ID" != "None" ]; then
    echo "Software installation command sent successfully. CommandId: $COMMAND_ID"
    exit 0
  else
    echo "Failed to send software installation command. Retrying in $RETRY_DELAY seconds..."
    sleep "$RETRY_DELAY"
  fi
done

echo "Failed to send software installation command after $MAX_RETRIES attempts."
exit 1