#!/bin/bash
set -e

if [ "$IS_PRIMARY_REGION" = "true" ]; then
  echo "[CLUSTER-SETUP] Installing AWS Load Balancer Controller CRDs..."
  kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml --timeout=60s
  kubectl wait --for condition=established --timeout=60s crd/targetgroupbindings.elbv2.k8s.aws || true
  
  echo "[CLUSTER-SETUP] Installing AWS Load Balancer Controller..."
  helm repo add eks https://aws.github.io/eks-charts || true
  helm repo update
  helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=true \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$LBC_ROLE_ARN \
    --set region=$AWS_REGION \
    --set vpcId=$VPC_ID \
    --wait --timeout 3m
  
  echo "[CLUSTER-SETUP] Restarting controller..."
  kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
  kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s
  
  if [ "$ENABLE_CERT_MANAGER" = "true" ]; then
    echo "[CLUSTER-SETUP] Installing Cert Manager..."
    helm repo add jetstack https://charts.jetstack.io || true
    helm repo update
    helm upgrade --install cert-manager jetstack/cert-manager \
      --version v1.16.2 \
      --namespace cert-manager \
      --create-namespace \
      --set crds.enabled=true \
      --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$CERT_MANAGER_ROLE_ARN \
      --wait --timeout 10m
  fi
else
  echo "[CLUSTER-SETUP] Skipping AWS Load Balancer Controller (not primary region)"
fi