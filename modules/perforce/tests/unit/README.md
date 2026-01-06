# Perforce Module Unit Tests

This directory contains mock-based unit tests for the Perforce wrapper module. These tests validate the conditional logic and resource creation without requiring AWS credentials or deploying actual infrastructure.

## Overview

The Perforce module is a **wrapper module** that orchestrates the deployment of three submodules:

- **P4 Server** (`modules/p4-server/`) - Perforce Helix Core version control server
- **P4 Auth** (`modules/p4-auth/`) - Perforce authentication service
- **P4 Code Review** (`modules/p4-code-review/`) - Perforce Swarm code review platform

Unit tests ensure that:

- Submodules are created only when their configuration is provided
- Shared resources (ECS cluster, load balancers, Route53) are created correctly
- Various combinations of submodules work without conflicts

## Test Files

### `01_conditional_creation.tftest.hcl`

**Purpose:** Validates that submodules are conditionally created based on configuration

**Test Scenarios (8 total):**

1. `no_submodules` - No configuration provided, no resources created
2. `p4_server_only` - Only P4 Server deployed
3. `p4_auth_only` - Only P4 Auth deployed
4. `p4_code_review_only` - Only P4 Code Review deployed (note: depends on P4 Server for credentials)
5. `server_and_auth` - P4 Server + P4 Auth combination
6. `server_and_code_review` - P4 Server + P4 Code Review combination
7. `full_stack` - All three submodules deployed together
8. `full_stack_existing_ecs_cluster` - Full stack using an existing ECS cluster

**Key Validations:**

- `length(module.p4_server)` equals 0 or 1 based on configuration
- `length(module.p4_auth)` equals 0 or 1 based on configuration
- `length(module.p4_code_review)` equals 0 or 1 based on configuration
- ECS cluster creation logic based on web service deployment

### `02_shared_resources.tftest.hcl`

**Purpose:** Validates shared resource creation logic

**Test Scenarios (6 total):**

1. `ecs_cluster_auth_only` - ECS cluster created for Auth service
2. `ecs_cluster_code_review_only` - ECS cluster created for Code Review service
3. `ecs_cluster_shared` - Single ECS cluster shared by both services
4. `route53_private_zone` - Private hosted zone and DNS records
5. `load_balancer_access_logs` - S3 bucket for LB access logs
6. `no_ecs_cluster_server_only` - No ECS cluster when only P4 Server is deployed

**Key Validations:**

- `local.create_shared_ecs_cluster` logic correctness
- Route53 zone and record configurations
- S3 bucket creation for access logs
- Load balancer configurations

## Running Tests

### Run All Unit Tests

From the module root directory:

```bash
cd /path/to/modules/perforce
terraform test
```

### Run Specific Test File

```bash
terraform test -filter=tests/unit/01_conditional_creation.tftest.hcl
```

### Run Specific Test Scenario

```bash
terraform test -filter=tests/unit/01_conditional_creation.tftest.hcl -verbose
```

## Mock Providers

All test files use mock providers to simulate AWS resources without making actual API calls:

- **aws** - Mocks AWS provider with data sources for region, caller identity, ELB service account, ECS cluster, IAM policy documents, and AMI
- **awscc** - Mocks AWS Cloud Control provider
- **random** - Mocks random provider
- **null** - Mocks null provider
- **local** - Mocks local provider
- **netapp-ontap** - Mocks NetApp ONTAP provider (for FSxN storage)

## Benefits of Unit Tests

✅ **Fast execution** - No actual resources created, tests complete in seconds
✅ **No AWS credentials required** - Mock providers eliminate need for authentication
✅ **Safe to run anywhere** - No risk of creating unexpected AWS resources
✅ **Comprehensive coverage** - Tests all conditional logic paths
✅ **Easy to debug** - Clear assertions with descriptive error messages
✅ **CI/CD friendly** - Can run in GitHub Actions without AWS access

## Test Maintenance

When modifying the Perforce module:

1. **Adding new submodules** - Add test scenarios to `01_conditional_creation.tftest.hcl`
2. **Adding shared resources** - Add test scenarios to `02_shared_resources.tftest.hcl`
3. **Changing conditional logic** - Update assertions to match new behavior
4. **Adding required variables** - Update all test scenarios with new variables

## Related Documentation

- [Integration Tests](../integration/README.md) - Tests that deploy actual infrastructure
- [Module README](../../README.md) - Main module documentation
- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
