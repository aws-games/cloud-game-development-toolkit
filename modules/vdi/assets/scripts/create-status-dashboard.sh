#!/bin/bash
# Create CloudWatch dashboard for VDI installation status

WORKSTATION_KEY=$1
INSTANCE_ID=$2
REGION=${3:-us-east-1}

# Create dashboard JSON
cat > /tmp/vdi-dashboard.json << EOF
{
  "widgets": [
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/ssm/run-command' | fields @timestamp, @message\n| filter @message like /Immediate.*$WORKSTATION_KEY/\n| sort @timestamp desc\n| limit 20",
        "region": "$REGION",
        "title": "VDI Installation Progress - $WORKSTATION_KEY",
        "view": "table"
      }
    }
  ]
}
EOF

# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "VDI-Status-$WORKSTATION_KEY" \
  --dashboard-body file:///tmp/vdi-dashboard.json

echo "Dashboard created: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=VDI-Status-$WORKSTATION_KEY"