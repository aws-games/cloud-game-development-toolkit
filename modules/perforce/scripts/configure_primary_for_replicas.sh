#!/bin/bash
REPLICA_LIST=$1

echo "Configuring primary server for replica support"
echo "Replica list: $REPLICA_LIST"

# Create replication service user
echo "Creating replication service user..."
p4 user -f -i <<EOF
User: replication-service
Type: service
Description: Service user for P4 replication
EOF

# Set password for replication user
echo "Setting replication user password..."
echo "replication123" | p4 passwd -P - replication-service

# Grant replication permissions
echo "Setting replication permissions..."
p4 protect -i <<EOF
Protections:
    super user * * //...
    super user replication-service * //...
EOF

# Enable journaling for replication
echo "Enabling journaling..."
p4 configure set journalPrefix=/p4/1/logs/journal
p4 configure set server.allowrewrite=1

echo "SUCCESS: Primary server configured for replication"