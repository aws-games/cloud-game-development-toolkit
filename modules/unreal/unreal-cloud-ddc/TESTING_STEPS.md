# Unreal Cloud DDC Module Testing Steps

## Overview

Comprehensive testing steps to validate module robustness, dependency handling, and proper resource lifecycle management.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- kubectl installed
- Valid Route53 hosted zone
- GitHub Personal Access Token stored in AWS Secrets Manager

## Test Categories

### 1. Basic Deployment Test

**Purpose**: Validate clean deployment from scratch

```bash
# 1. Initial deployment
terraform init
terraform plan
terraform apply

# 2. Verify infrastructure
aws eks update-kubeconfig --region us-east-1 --name cgd-unreal-cloud-ddc-dev
kubectl get pods -n unreal-cloud-ddc
kubectl get svc -n unreal-cloud-ddc

# 3. Test DDC endpoint
curl -k https://your-ddc-endpoint/health
```

### 2. Configuration Change Tests

**Purpose**: Validate non-destructive changes work correctly

#### 2.1 Environment Variable Changes
```hcl
# Change in locals.tf
environment = "staging"  # was "dev"
```

#### 2.2 Scaling Changes
```hcl
# Change node group configuration
ddc_infra_config = {
  # ... existing config
  scylla_config = {
    current_region = {
      replication_factor = 5  # was 3
    }
  }
}
```

### 3. **CRITICAL: Destructive Change Tests**

**Purpose**: Validate proper dependency handling during resource replacement

#### 3.1 Project Prefix Change (MOST DESTRUCTIVE)
```hcl
# Change in locals.tf
project_prefix = "new-cgd"  # was "cgd"
```

**Expected Behavior**:
- All resources with name prefixes should be replaced
- Dependencies should be handled correctly (no stuck resources)
- No manual intervention required
- Clean destroy → recreate cycle

**Test Steps**:
```bash
# 1. Make the change
# 2. Plan and verify massive replacement
terraform plan  # Should show many resources to replace
# 3. Apply and monitor for stuck resources
terraform apply
# 4. Verify new resources have correct naming
```

#### 3.2 Name Change
```hcl
# Change in locals.tf
name = "new-unreal-cloud-ddc"  # was "unreal-cloud-ddc"
```

#### 3.3 Region Change (EXTREMELY DESTRUCTIVE)
```hcl
# Change in locals.tf
region = "us-west-2"  # was "us-east-1"
```

### 4. Network Configuration Tests

#### 4.1 VPC Change
```hcl
# Point to different VPC
vpc_id = aws_vpc.new_vpc.id
```

#### 4.2 Subnet Changes
```hcl
# Change subnet configuration
eks_node_group_subnets = aws_subnet.new_private[*].id
```

### 5. Security Configuration Tests

#### 5.1 CIDR Changes
```hcl
allowed_external_cidrs = ["10.0.0.0/8"]  # was specific IP
```

#### 5.2 Certificate Changes
```hcl
certificate_arn = aws_acm_certificate.new_cert.arn
```

### 6. Load Balancer Tests

#### 6.1 Internet Facing Toggle
```hcl
load_balancers_config = {
  nlb = {
    internet_facing = false  # was true
    subnets         = aws_subnet.private[*].id  # was public
  }
}
```

### 7. Application Configuration Tests

#### 7.1 Namespace Changes
```hcl
ddc_application_config = {
  ddc_namespaces = {
    "new-project1" = {  # was "project1"
      description = "Renamed project"
    }
    "project3" = {  # new namespace
      description = "Additional project"
    }
    # Remove "project2" - test deletion
  }
}
```

## Critical Test Scenarios

### Scenario A: Complete Infrastructure Refresh
1. Deploy initial infrastructure
2. Change `project_prefix` to trigger mass replacement
3. Verify no resources get stuck in deletion
4. Verify all new resources are created successfully
5. Verify application functionality post-replacement

### Scenario B: Dependency Chain Validation
1. Deploy infrastructure
2. Make changes that affect multiple resource types simultaneously:
   - Change `project_prefix`
   - Change `environment`
   - Change `vpc_id`
3. Verify Terraform handles complex dependency chains correctly

### Scenario C: Rollback Testing
1. Deploy infrastructure
2. Make destructive changes
3. Revert changes
4. Verify infrastructure returns to original state

## Validation Checklist

After each test, verify:

- [ ] **No stuck resources**: Check AWS console for resources in "deleting" state
- [ ] **Proper naming**: All resources follow new naming conventions
- [ ] **Functional endpoints**: DDC service responds correctly
- [ ] **EKS cluster health**: All pods running, nodes ready
- [ ] **ScyllaDB cluster**: All nodes connected, proper replication
- [ ] **Load balancer**: Health checks passing, traffic routing correctly
- [ ] **Security groups**: Rules applied correctly, no 0.0.0.0/0 violations
- [ ] **Logging**: CloudWatch logs flowing correctly

## Common Issues to Watch For

### Resource Deletion Issues
- Target groups stuck due to listener references
- Internet gateways stuck due to VPC dependencies
- Security groups stuck due to ENI attachments
- EKS cluster stuck due to node group dependencies

### Dependency Violations
- Resources created before dependencies are ready
- Circular dependencies in security group rules
- Load balancer listeners referencing non-existent target groups

### State Corruption
- Resources in Terraform state but not in AWS
- Resources in AWS but not in Terraform state
- Mismatched resource attributes

## Recovery Procedures

### If Resources Get Stuck
```bash
# 1. Identify stuck resources in AWS console
# 2. Manual cleanup (example for load balancer)
aws elbv2 delete-listener --listener-arn <arn>
aws elbv2 delete-target-group --target-group-arn <arn>
aws elbv2 delete-load-balancer --load-balancer-arn <arn>

# 3. Remove from Terraform state
terraform state rm 'module.unreal_cloud_ddc.module.ddc_infra.aws_lb_listener.https'

# 4. Re-run terraform apply
terraform apply
```

### If State Gets Corrupted
```bash
# 1. Backup current state
cp terraform.tfstate terraform.tfstate.backup

# 2. Import missing resources
terraform import 'resource.name' resource-id

# 3. Refresh state
terraform refresh
```

## Success Criteria

A test passes if:
1. **No manual intervention required** during apply
2. **All resources created/updated/destroyed** as planned
3. **Application remains functional** after changes
4. **No orphaned resources** left in AWS
5. **Terraform state remains consistent** with actual infrastructure

## Test Documentation

For each test, document:
- **Test scenario**: What was changed
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happened
- **Issues encountered**: Any problems or manual steps required
- **Resolution**: How issues were resolved
- **Lessons learned**: Improvements needed in module

## Automation Potential

Consider automating these tests in CI/CD:
- Use separate AWS accounts for destructive testing
- Implement test teardown procedures
- Create test matrices for different configuration combinations
- Add monitoring for stuck resources during tests