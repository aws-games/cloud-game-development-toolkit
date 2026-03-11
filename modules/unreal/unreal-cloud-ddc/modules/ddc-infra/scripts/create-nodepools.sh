#!/bin/bash
set -e

echo "[NODEPOOL-CREATE] Creating NodeClass with IAM role: $NODE_ROLE_NAME"
echo "[NODEPOOL-CREATE] NODE_SUBNETS: $NODE_SUBNETS"

# Build NodeClass manifest in steps to ensure proper variable expansion
cat <<EOF > /tmp/nodeclass.yaml
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: ddc-nodeclass
spec:
  role: $NODE_ROLE_NAME
  subnetSelectorTerms:
EOF

# Process and append subnet IDs
echo "$NODE_SUBNETS" | tr "," "\n" | sed "s/^/    - id: /" >> /tmp/nodeclass.yaml

# Append remaining spec
cat <<EOF >> /tmp/nodeclass.yaml
  securityGroupSelectorTerms:
    - id: $CLUSTER_SG_ID
  ephemeralStorage:
    iops: 3000
    size: 80Gi
    throughput: 125
  networkPolicy: DefaultAllow
  snatPolicy: Random
  tags:
    Name: "$NAME_PREFIX-ddc-node"
    Purpose: "DDC-NVMe-Storage"
    NodePool: "ddc-compute"
    StorageType: "NVMe-Primary-EBS-Fallback"
    Cluster: "$NAME_PREFIX-cluster-$AWS_REGION"
EOF

# Apply the NodeClass
kubectl apply -f /tmp/nodeclass.yaml

echo "[NODEPOOL-CREATE] Creating DDC NodePool..."
kubectl apply -f - <<EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ddc-compute
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: ddc-nodeclass
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: eks.amazonaws.com/instance-local-nvme
          operator: Gt
          values: ["100"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
      terminationGracePeriod: 24h0m0s
  disruption:
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
    budgets:
      - nodes: "10%"
EOF