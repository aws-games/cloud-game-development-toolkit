#!/bin/bash
PRIMARY_FQDN=$1
REPLICA_TYPE=$2

echo "Configuring replica: $REPLICA_TYPE"
echo "Primary server: $PRIMARY_FQDN:1666"

# Test connection to primary with retry logic
echo "Testing connection to primary server..."
for i in {1..10}; do
  P4_OUTPUT=$(p4 -p $PRIMARY_FQDN:1666 info 2>&1)
  P4_EXIT_CODE=$?
  
  if [ $P4_EXIT_CODE -eq 0 ]; then
    echo "SUCCESS: Connected to primary server on attempt $i"
    break
  fi
  
  echo "ATTEMPT $i FAILED: $P4_OUTPUT"
  if [ $i -eq 10 ]; then
    echo "ERROR: Cannot connect to primary server $PRIMARY_FQDN:1666 after 10 attempts"
    echo "Common causes:"
    echo "- Primary server not running (check EC2 instance status)"
    echo "- Network connectivity issues (check security groups/NACLs)"
    echo "- DNS resolution failure (check Route53 records)"
    echo "- Perforce service not started on primary"
    exit 1  # Connection failure
  fi
  sleep 30
done

# Configure replica based on type
echo "Configuring replica type: $REPLICA_TYPE"
case $REPLICA_TYPE in
  "standby")
    echo "Setting up standby replica..."
    if ! p4 configure set P4TARGET=$PRIMARY_FQDN:1666; then
      echo "ERROR: Failed to set replication target"
      exit 2
    fi
    p4 configure set server.id=standby-replica
    p4 configure set rpl.journalcopy.enable=1
    p4 configure set rpl.journalcopy.location=/p4/1/logs/journal
    ;;
  "forwarding")
    echo "Setting up forwarding replica..."
    if ! p4 configure set P4TARGET=$PRIMARY_FQDN:1666; then
      echo "ERROR: Failed to set replication target"
      exit 2
    fi
    p4 configure set server.id=forwarding-replica
    p4 configure set rpl.forward.enable=1
    p4 configure set rpl.pull.enable=1
    ;;
  "readonly")
    echo "Setting up readonly replica..."
    if ! p4 configure set P4TARGET=$PRIMARY_FQDN:1666; then
      echo "ERROR: Failed to set replication target"
      exit 2
    fi
    p4 configure set server.id=readonly-replica
    p4 configure set rpl.pull.enable=1
    ;;
  "edge")
    echo "Setting up edge replica..."
    if ! p4 configure set P4TARGET=$PRIMARY_FQDN:1666; then
      echo "ERROR: Failed to set replication target"
      exit 2
    fi
    p4 configure set server.id=edge-replica
    p4 configure set rpl.pull.enable=1
    p4 configure set rpl.pull.reload=1
    ;;
  *)
    echo "ERROR: Unknown replica type: $REPLICA_TYPE"
    echo "Supported types: standby, forwarding, readonly, edge"
    exit 3  # Invalid replica type
    ;;
esac

# Start replication
echo "Starting replication process..."
if ! p4d -r /p4/1 -p 1666 -d; then
  echo "ERROR: Failed to start Perforce daemon"
  exit 4  # Daemon start failure
fi

# Verify replication is working
echo "Verifying replication..."
sleep 10
if p4 pull -l | grep -q "up-to-date"; then
  echo "SUCCESS: Replica configured and replication active"
else
  echo "WARNING: Replication may not be fully synchronized yet"
fi

echo "SUCCESS: Replica $REPLICA_TYPE configured successfully"