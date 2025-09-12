# Kubectl Workflow Rule

## EKS Context Setup

**ALWAYS provide the `aws eks update-kubeconfig` command FIRST before any kubectl commands.**

### Pattern
```bash
# Step 1: Update kubeconfig (ALWAYS FIRST)
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Step 2: Then kubectl commands
kubectl get pods -n <namespace>
```

### Why This Matters
- Users need EKS context configured before kubectl works
- Saves users from having to ask for the kubeconfig command every time
- Provides complete, executable workflow

### Examples
```bash
# EKS cluster access (ALWAYS FIRST)
aws eks update-kubeconfig --region us-east-1 --name cgd-unreal-cloud-ddc-cluster-us-east-1

# Then kubectl operations
kubectl get pods -n unreal-cloud-ddc
kubectl logs -f pod-name -n namespace
kubectl describe pod pod-name -n namespace
```

**Remember: EKS kubeconfig setup is ALWAYS the first step in any kubectl workflow.**