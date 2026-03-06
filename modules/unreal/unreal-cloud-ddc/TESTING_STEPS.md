# Unreal Cloud DDC Module Testing

## Overview

The DDC module uses **automated CodeBuild testing** - just run `terraform apply` and watch the progress in AWS Console. Manual testing scripts are also available for local validation.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.14.0
- Valid Route53 hosted zone
- GitHub Personal Access Token stored in AWS Secrets Manager (with access to Epic Games GitHub Org)
- VPC with private subnets and NAT Gateway (for CodeBuild)

## Automated Testing (Recommended)

### Single Region Test

```bash
# Navigate to example
cd examples/single-region-basic

# Deploy and test automatically
terraform init
terraform plan
terraform apply
```

**What happens automatically:**
1. **Infrastructure deployment** - EKS cluster, ScyllaDB, networking
2. **CodeBuild execution** - 3 projects run in sequence:
   - `cluster-setup` - Karpenter NodePools for DDC compute nodes
   - `ddc-deployer` - DDC application deployment
   - `ddc-tester` - Comprehensive functional testing
3. **Real-time monitoring** - Watch progress in AWS Console → CodeBuild

### Multi-Region Test

```bash
# Navigate to multi-region example
cd examples/multi-region-basic

# Deploy and test automatically
terraform init
terraform plan
terraform apply
```

**Additional validation:**
- Cross-region ScyllaDB replication
- Multi-region DDC functionality
- DNS endpoint testing for both regions

### Monitoring CodeBuild Progress

**AWS Console → CodeBuild:**
1. **cluster-setup-[region]** - Karpenter NodePool creation logs
2. **ddc-deployer-[region]** - Application deployment logs  
3. **ddc-tester-[region]** - Functional test results

**Success indicators:**
- ✅ All CodeBuild projects show "Succeeded"
- ✅ DDC functional tests pass (PUT/GET operations)
- ✅ Health endpoints responding
- ✅ Cross-region replication working (multi-region)

## Manual Testing (Optional)

### Local Test Scripts

```bash
# Single region testing
cd modules/unreal/unreal-cloud-ddc
./assets/scripts/ddc_functional_test.sh

# Multi-region testing
./assets/scripts/ddc_functional_test_multi_region.sh
```

**Note:** These scripts require Terraform outputs and are mainly for debugging.

### Manual kubectl Access

```bash
# Access EKS cluster
aws eks update-kubeconfig --region us-east-1 --name cgd-unreal-cloud-ddc-cluster-us-east-1

# Check DDC pods
kubectl get pods -n unreal-cloud-ddc
kubectl get svc -n unreal-cloud-ddc

# View logs
kubectl logs -f deployment/unreal-cloud-ddc -n unreal-cloud-ddc
```

## Validation Checklist

### Automated Testing Success
- [ ] **Terraform apply** completes without errors
- [ ] **CodeBuild projects** all show "Succeeded" status
- [ ] **DDC functional tests** pass in CodeBuild logs
- [ ] **No manual intervention** required

### Infrastructure Health
- [ ] **EKS cluster** accessible via kubectl
- [ ] **DDC pods** running and ready
- [ ] **Load balancer** health checks passing
- [ ] **DNS endpoints** resolving (may take 15-30 minutes)

### Clean Destruction
```bash
terraform destroy
```
- [ ] **All resources** destroyed cleanly
- [ ] **No stuck resources** in AWS Console
- [ ] **Cleanup scripts** handle EKS Auto Mode security groups

## Troubleshooting

### CodeBuild Failures

**Check CodeBuild logs in AWS Console for:**
- VPC connectivity issues (NAT Gateway)
- IAM permission problems
- EKS authentication failures
- DDC application startup issues

### Common Issues

**DNS propagation delays:**
- CodeBuild tests handle DNS caching automatically
- May take 15-30 minutes for global DNS propagation
- Tests use Google DNS (8.8.8.8) as fallback

**EKS Auto Mode cleanup:**
- Module includes automatic cleanup scripts
- Handles orphaned security groups and DNS records
- No manual intervention needed

**ScyllaDB startup timing:**
- CodeBuild tests include retry logic
- Waits for schema agreement before testing
- Multi-region replication may need extra time

## Success Criteria

**Single Region:**
- ✅ `terraform apply` completes successfully
- ✅ All 3 CodeBuild projects succeed
- ✅ DDC PUT/GET operations work
- ✅ `terraform destroy` cleans up completely

**Multi-Region:**
- ✅ Both regions deploy successfully
- ✅ Cross-region replication verified
- ✅ Both regional endpoints functional
- ✅ Clean destruction of both regions

## Key Benefits of Automated Testing

1. **No manual steps** - Everything automated via CodeBuild
2. **Real-time monitoring** - Watch progress in AWS Console
3. **Comprehensive validation** - Infrastructure + application + functional tests
4. **Retry logic** - Handles DNS propagation and startup timing
5. **Clean reporting** - Clear success/failure indicators
6. **Consistent results** - Same tests run every time