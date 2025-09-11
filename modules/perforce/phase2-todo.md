# Phase 2: Cross-Region Replica Support - Implementation Plan

## Overview
Phase 2 extends Phase 1's same-region replica support to enable true cross-region P4 server replicas for global development teams and disaster recovery.

## Current State (Phase 1)
✅ Same-region replicas working (multi-AZ within single region)
✅ Basic replica infrastructure (S3, SSM, Route53, IAM)
✅ Replica inheritance and validation
❌ Cross-region functionality is placeholder only

## Phase 2 Requirements

### 1. Cross-Region Detection & Provider Handling
**Goal**: Automatically detect when replicas are in different regions and use appropriate providers

**Implementation**:
- Add `region` field to `p4_server_replicas_config` variable
- Create `data.aws_region.current` to get primary region
- Add logic to detect cross-region replicas: `each.value.region != data.aws_region.current.name`
- Implement provider selection logic for cross-region resources

**Files to modify**:
- `modules/perforce/variables.tf` - Add region field
- `modules/perforce/main.tf` - Add region detection logic
- `modules/perforce/providers.tf` - Define required providers

### 2. Cross-Region IAM Policies
**Goal**: Enable replicas to access primary region resources (S3, Secrets Manager, SSM)

**Implementation**:
- Modify IAM policies to include cross-region resource ARNs
- Add permissions for cross-region S3 access
- Add permissions for cross-region Secrets Manager access
- Add permissions for cross-region SSM execution

**Files to modify**:
- `modules/perforce/modules/p4-server/iam.tf` - Update IAM policies
- Add cross-region resource ARN patterns

### 3. Provider-Aware Resource Creation
**Goal**: Create resources in correct regions using provider aliases

**Implementation**:
- Modify replica module calls to use region-specific providers
- Update S3 bucket access for cross-region scenarios
- Handle AWSCC vs AWS provider differences across regions
- Implement provider selection logic

**Files to modify**:
- `modules/perforce/main.tf` - Provider-aware module calls
- `modules/perforce/s3.tf` - Cross-region S3 access
- `modules/perforce/ssm.tf` - Cross-region SSM execution

### 4. Cross-Region DNS Management
**Goal**: Manage DNS records across regions with health checks

**Implementation**:
- Create Route53 health checks for cross-region replicas
- Implement failover routing policies
- Add latency-based routing for global teams
- Handle cross-region certificate management

**Files to modify**:
- `modules/perforce/route53.tf` - Cross-region DNS logic
- Add health check resources
- Add routing policy configuration

### 5. Network Connectivity Validation
**Goal**: Validate that cross-region networking is properly configured

**Implementation**:
- Add validation for VPC peering/Transit Gateway connectivity
- Validate security group rules for cross-region traffic
- Add network connectivity checks
- Provide clear error messages for missing networking

**Files to modify**:
- `modules/perforce/variables.tf` - Add networking validations
- `modules/perforce/networking.tf` - New file for network checks

### 6. Enhanced Examples
**Goal**: Provide working cross-region examples with proper networking

**Implementation**:
- Update `replica-cross-region` example with real cross-region setup
- Add VPC peering configuration
- Add cross-region security group rules
- Add Transit Gateway example (optional)

**Files to modify**:
- `modules/perforce/examples/replica-cross-region/` - Complete rewrite
- Add networking infrastructure
- Add proper provider configuration

## Implementation Tasks

### Task 1: Core Cross-Region Logic (Week 1)
- [ ] Add `region` field to replica configuration
- [ ] Implement region detection logic
- [ ] Add provider selection mechanism
- [ ] Update variable validations

### Task 2: Cross-Region IAM & Security (Week 2)  
- [ ] Update IAM policies for cross-region access
- [ ] Add cross-region S3 permissions
- [ ] Add cross-region Secrets Manager permissions
- [ ] Test cross-region resource access

### Task 3: Provider-Aware Resources (Week 3)
- [ ] Implement provider-specific resource creation
- [ ] Update S3 bucket access patterns
- [ ] Update SSM execution for cross-region
- [ ] Handle AWSCC provider differences

### Task 4: DNS & Health Checks (Week 4)
- [ ] Implement Route53 health checks
- [ ] Add failover routing policies
- [ ] Add latency-based routing
- [ ] Test DNS failover scenarios

### Task 5: Network Validation (Week 5)
- [ ] Add VPC connectivity validation
- [ ] Add security group validation
- [ ] Implement network connectivity tests
- [ ] Add clear error messaging

### Task 6: Cross-Region Example (Week 6)
- [ ] Rewrite cross-region example
- [ ] Add VPC peering setup
- [ ] Add cross-region security groups
- [ ] Add comprehensive testing
- [ ] Update documentation

## Technical Challenges

### Provider Alias Complexity
- Terraform modules with provider aliases are complex
- Need to handle dynamic provider selection
- AWSCC provider differences across regions

### IAM Cross-Region Permissions
- Resource ARNs must include all regions
- Secrets Manager cross-region access patterns
- S3 cross-region bucket policies

### Network Dependencies
- VPC peering must exist before replica creation
- Security groups must allow cross-region traffic
- DNS resolution across regions

### State Management
- Cross-region resources in single state file
- Provider configuration complexity
- Dependency ordering across regions

## Success Criteria

### Functional Requirements
- [ ] Replicas deploy successfully in different regions
- [ ] Cross-region replication works (P4 sync from remote replica)
- [ ] Failover works (promote replica in different region)
- [ ] DNS routing works (latency-based, health check-based)

### Performance Requirements
- [ ] Cross-region latency < 200ms for most operations
- [ ] Failover time < 15 minutes
- [ ] Health check detection < 5 minutes

### Operational Requirements
- [ ] Clear error messages for networking issues
- [ ] Comprehensive validation of prerequisites
- [ ] Working examples with full networking setup
- [ ] Documentation for cross-region setup

## Dependencies on Phase 1
- Phase 1 replica infrastructure (S3, SSM, Route53)
- Phase 1 validation logic
- Phase 1 inheritance patterns
- Phase 1 IAM foundation

## Risk Mitigation
- Start with simple 2-region setup
- Extensive testing of provider alias patterns
- Validate networking prerequisites early
- Provide fallback to same-region if cross-region fails
- Clear documentation of networking requirements

## Future Enhancements (Phase 3)
- Multi-region mesh topology
- Automatic network setup (Transit Gateway)
- Advanced routing policies
- Cross-region backup/restore
- Global load balancing