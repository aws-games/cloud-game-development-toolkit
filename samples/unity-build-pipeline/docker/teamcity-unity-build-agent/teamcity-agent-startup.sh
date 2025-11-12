#!/bin/bash
set -e

echo "Starting TeamCity Build Agent..."

# Check if SERVER_URL is set
if [ -z "$SERVER_URL" ]; then
    echo "ERROR: SERVER_URL environment variable is not set"
    exit 1
fi

# Download TeamCity agent if not already present
if [ ! -f /opt/buildAgent/bin/agent.sh ]; then
    echo "Downloading TeamCity agent from $SERVER_URL..."

    # Download buildAgent.zip from TeamCity server
    wget -q -O /tmp/buildAgent.zip "${SERVER_URL}/update/buildAgent.zip"

    # Extract to buildAgent directory
    unzip -q /tmp/buildAgent.zip -d /opt/buildAgent
    rm /tmp/buildAgent.zip

    echo "TeamCity agent downloaded and extracted"
fi

# Configure agent name if provided
if [ -n "$AGENT_NAME" ]; then
    echo "Setting agent name to: $AGENT_NAME"
    echo "name=$AGENT_NAME" > /opt/buildAgent/conf/buildAgent.properties
fi

# Set server URL in buildAgent.properties
echo "serverUrl=$SERVER_URL" >> /opt/buildAgent/conf/buildAgent.properties

# Start the agent
echo "Starting TeamCity agent..."
exec /opt/buildAgent/bin/agent.sh run
