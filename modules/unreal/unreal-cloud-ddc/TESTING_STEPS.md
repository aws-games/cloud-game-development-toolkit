# Unreal Cloud DDC Module Testing Steps

## Overview

Comprehensive testing steps to validate the CodeBuild + Terraform Actions refactor, ensuring reliable deployment and proper dependency handling.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- Valid Route53 hosted zone
- GitHub Personal Access Token stored in AWS Secrets Manager
- VPC with private subnets and NAT Gateway (for CodeBuild)

## Core Testing Workflow

### 1. Single Region Deployment Test

**Purpose**: Validate complete single-region deployment with CodeBuild automation

#### 1.1 Initial Deployment
```bash
# Navigate to single-region example
cd examples/single-region-basic

# Deploy infrastructure
terraform init
terraform plan
terraform apply
```

**Expected Results**:
- ✅ EKS cluster created successfully
- ✅ ScyllaDB cluster deployed
- ✅ CodeBuild projects created (cluster-setup, ddc-deployer, ddc-tester)
- ✅ All CodeBuild executions complete successfully
- ✅ DDC application pods running
- ✅ Load balancer health checks passing

#### 1.2 Validate CodeBuild Execution
```bash
# Check CodeBuild execution logs in AWS Console:
# 1. cluster-setup project - AWS Load Balancer Controller, Cert Manager, NodePools
# 2. ddc-deployer project - DDC application deployment
# 3. ddc-tester project - DDC functionality validation

# Verify EKS cluster access
aws eks update-kubeconfig --region us-east-1 --name cgd-unreal-cloud-ddc-cluster-us-east-1
kubectl get pods -n unreal-cloud-ddc
kubectl get svc -n unreal-cloud-ddc
```

#### 1.3 Run Local DDC Test Script
```bash
# Test DDC functionality locally
cd ../../modules/unreal/unreal-cloud-ddc
./scripts/test-ddc-single-region.sh
```

**Expected Results**:
- ✅ DDC endpoint responds to health checks
- ✅ Cache operations work correctly
- ✅ Authentication successful

### 2. No-Change Plan Validation

**Purpose**: Verify idempotency - no changes should be detected

```bash
# From examples/single-region-basic
terraform plan
```

**Expected Results**:
- ✅ "No changes. Your infrastructure matches the configuration."
- ✅ No CodeBuild executions triggered

### 3. CodeBuild Trigger Tests

**Purpose**: Validate that small changes properly trigger CodeBuild executions

#### 3.1 Cluster Setup Trigger Test
```bash
# Make small change to trigger cluster-setup CodeBuild
# Edit terraform.tfvars or main.tf to add a comment or change a tag
echo '# Test comment' >> main.tf

terraform plan
# Should show terraform_data.cluster_setup_trigger will be replaced

terraform apply
# Verify cluster-setup CodeBuild project executes

# Revert change
git checkout -- main.tf
terraform plan
# Should show no changes again
```

#### 3.2 DDC App Deploy Trigger Test
```bash
# Make change that affects ddc-app submodule
# Edit ddc_application_config in terraform.tfvars
# Add a comment or change namespace description

terraform plan
# Should show terraform_data.deploy_trigger will be replaced

terraform apply
# Verify ddc-deployer CodeBuild project executes
# Verify ddc-tester CodeBuild project executes after deploy completes

# Revert change
terraform plan
# Should show no changes
```

#### 3.3 DDC App Test Trigger Test
```bash
# Make change that affects test configuration
# Edit debug flag or test-related variable

terraform plan
terraform apply
# Verify ddc-tester CodeBuild project executes

# Revert and verify no changes
```

### 4. Single Region Cleanup

**Purpose**: Validate clean destruction

```bash
# From examples/single-region-basic
terraform destroy
```

**Expected Results**:
- ✅ All resources destroyed cleanly
- ✅ No stuck resources in AWS console
- ✅ No manual intervention required

### 5. Multi-Region Deployment Test

**Purpose**: Validate multi-region deployment with cross-region replication

#### 5.1 Multi-Region Deployment
```bash
# Navigate to multi-region example
cd examples/multi-region-basic

terraform init
terraform plan
terraform apply
```

**Expected Results**:
- ✅ Both regions deploy successfully
- ✅ Cross-region ScyllaDB replication configured
- ✅ Multi-region CodeBuild tests pass
- ✅ DNS endpoints for both regions working

#### 5.2 Multi-Region Validation
```bash
# Test both regional endpoints
aws eks update-kubeconfig --region us-east-1 --name cgd-unreal-cloud-ddc-cluster-us-east-1
kubectl get pods -n unreal-cloud-ddc

aws eks update-kubeconfig --region us-west-2 --name cgd-unreal-cloud-ddc-cluster-us-west-2
kubectl get pods -n unreal-cloud-ddc

# Run multi-region test script
cd ../../modules/unreal/unreal-cloud-ddc
./scripts/test-ddc-multi-region.sh
```

#### 5.3 Multi-Region CodeBuild Trigger Tests
```bash
# Repeat trigger tests from section 3 for multi-region
# Verify CodeBuild executions work in both regions
```

#### 5.4 Multi-Region Cleanup
```bash
terraform destroy
```

### 6. Single-to-Multi Region Migration Test

**Purpose**: Test adding/removing regions dynamically

#### 6.1 Deploy Single Region
```bash
# In examples/multi-region-basic
# Comment out the second region module in main.tf
# module "unreal_cloud_ddc_us_west_2" {
#   ...
# }

terraform init
terraform apply
# Verify single region deployment
```

#### 6.2 Add Second Region
```bash
# Uncomment the second region module
terraform plan
# Should show addition of second region resources

terraform apply
# Verify multi-region deployment works
# Verify cross-region replication configured
```

#### 6.3 Remove Second Region
```bash
# Comment out second region module again
terraform plan
# Should show removal of second region resources

terraform apply
# Verify clean removal of second region
# Verify first region continues working
```

#### 6.4 Final Cleanup
```bash
terraform destroy
# Verify complete cleanup
```

## Validation Checklist

After each test phase, verify:

### Infrastructure Health
- [ ] **EKS Cluster**: All nodes ready, system pods running
- [ ] **ScyllaDB**: All nodes connected, proper replication factor
- [ ] **Load Balancer**: Health checks passing, DNS resolution working
- [ ] **Security Groups**: Proper rules, no 0.0.0.0/0 violations
- [ ] **VPC Configuration**: CodeBuild running in private subnets

### CodeBuild Execution
- [ ] **Cluster Setup**: AWS Load Balancer Controller, Cert Manager, NodePools deployed
- [ ] **DDC Deployer**: Application pods running, services created
- [ ] **DDC Tester**: Functional tests passing, endpoints responding
- [ ] **CloudWatch Logs**: All CodeBuild executions logged properly
- [ ] **Dependency Order**: Test waits for deploy completion (workaround working)

### Application Functionality
- [ ] **DDC Endpoints**: Health checks responding
- [ ] **Cache Operations**: Put/Get operations working
- [ ] **Authentication**: Proper access controls
- [ ] **Multi-Region**: Cross-region replication (if applicable)

### Terraform State
- [ ] **Idempotency**: No changes on repeated plans
- [ ] **Trigger Logic**: Changes properly trigger CodeBuild
- [ ] **Clean Destruction**: All resources removed cleanly
- [ ] **State Consistency**: No orphaned resources

## Troubleshooting Guide

### CodeBuild Failures
```bash
# Check CodeBuild logs in AWS Console
# Common issues:
# 1. VPC connectivity - ensure NAT Gateway working
# 2. IAM permissions - check CodeBuild service role
# 3. EKS authentication - verify RBAC configuration
# 4. Dependency timing - check workaround script execution
```

### EKS Access Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check cluster status
aws eks describe-cluster --region <region> --name <cluster-name>

# Verify node groups
kubectl get nodes
kubectl get pods -A
```

### DDC Application Issues
```bash
# Check pod status
kubectl get pods -n unreal-cloud-ddc
kubectl describe pod <pod-name> -n unreal-cloud-ddc
kubectl logs <pod-name> -n unreal-cloud-ddc

# Check services and endpoints
kubectl get svc -n unreal-cloud-ddc
kubectl get endpoints -n unreal-cloud-ddc
```

### Load Balancer Issues
```bash
# Check NLB status
aws elbv2 describe-load-balancers
aws elbv2 describe-target-health --target-group-arn <arn>

# Check security group rules
aws ec2 describe-security-groups --group-ids <sg-id>
```

## Success Criteria

All tests pass if:

1. **Single Region Deployment**: Complete deployment in one `terraform apply`
2. **CodeBuild Integration**: All three CodeBuild projects execute successfully
3. **Application Functionality**: DDC endpoints respond and cache operations work
4. **Idempotency**: No changes detected on repeated plans
5. **Change Detection**: Small changes properly trigger CodeBuild executions
6. **Clean Destruction**: All resources destroyed without manual intervention
7. **Multi-Region Support**: Cross-region replication and testing work
8. **Migration Scenarios**: Adding/removing regions works cleanly

## Test Documentation Template

For each test execution, document:

```markdown
## Test Execution: [Date/Time]

### Test Phase: [e.g., Single Region Deployment]

**Environment**:
- AWS Account: [account-id]
- Regions: [us-east-1, us-west-2]
- Terraform Version: [version]

**Results**:
- [ ] Infrastructure deployment: ✅/❌
- [ ] CodeBuild executions: ✅/❌
- [ ] Application functionality: ✅/❌
- [ ] Clean destruction: ✅/❌

**Issues Encountered**:
- [List any issues and resolutions]

**CodeBuild Execution Times**:
- cluster-setup: [duration]
- ddc-deployer: [duration]
- ddc-tester: [duration]

**Notes**:
- [Any additional observations]
```

## Automation Recommendations

For CI/CD integration:

1. **Separate AWS Accounts**: Use dedicated accounts for testing
2. **Parallel Testing**: Run single and multi-region tests in parallel
3. **Resource Monitoring**: Alert on stuck resources during destruction
4. **Log Aggregation**: Collect CodeBuild logs for analysis
5. **Performance Tracking**: Monitor CodeBuild execution times
6. **State Backup**: Backup Terraform state before destructive tests