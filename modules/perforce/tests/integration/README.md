# Perforce Module Integration Tests

This directory contains integration tests that validate the Perforce module against real AWS infrastructure by invoking the example deployments.

## Overview

Integration tests differ from unit tests in that they:

- **Use real AWS resources** - Actual infrastructure is deployed (in plan mode for safety)
- **Test example deployments** - Validates that examples work correctly
- **Require AWS credentials** - Must have valid AWS authentication configured
- **Use SSM parameters** - Fetch configuration values from AWS Systems Manager Parameter Store

## Test Files

### `01_create_resources_complete.tftest.hcl`

**Purpose:** Validates the complete Perforce deployment example

**Example Invoked:** `examples/create-resources-complete`

**Required SSM Parameters:**

- `/cloud-game-development-toolkit/modules/perforce/route53-public-hosted-zone-name`

**Test Flow:**

1. `setup` run - Fetches Route53 zone name from SSM Parameter Store
2. `unit_test` run - Plans the complete example deployment using fetched parameters

### `02_p4_server_fsxn.tftest.hcl`

**Purpose:** Validates P4 Server deployment with FSxN (NetApp ONTAP) storage

**Example Invoked:** `examples/p4-server-fsxn`

**Required SSM Parameters:**

- `/cloud-game-development-toolkit/modules/perforce/route53-public-hosted-zone-name`
- `/cloud-game-development-toolkit/modules/perforce/fsxn-password`
- `/cloud-game-development-toolkit/modules/perforce/fsxn-aws-profile`

**Test Flow:**

1. `setup` run - Fetches FSxN configuration from SSM Parameter Store
2. `unit_test` run - Plans the FSxN example deployment using fetched parameters

## Setup Module

The `setup/` directory contains a Terraform module that fetches test configuration from AWS Systems Manager Parameter Store.

**Files:**

- `setup/ssm.tf` - Data sources for SSM parameters and outputs
- `setup/versions.tf` - Terraform and provider version constraints

**Purpose:** Centralizes test configuration management and avoids hardcoding sensitive values in test files.

## Running Integration Tests

### Prerequisites

1. **AWS Credentials** - Configure AWS authentication:

   ```bash
   export AWS_PROFILE=your-profile
   # OR
   export AWS_ACCESS_KEY_ID=xxx
   export AWS_SECRET_ACCESS_KEY=xxx
   ```

2. **SSM Parameters** - Create required parameters in your AWS account:

   ```bash
   aws ssm put-parameter \
     --name "/cloud-game-development-toolkit/modules/perforce/route53-public-hosted-zone-name" \
     --value "your-domain.com" \
     --type String
   ```

### Run All Integration Tests

From the module root directory:

```bash
cd /path/to/modules/perforce
terraform test -filter=tests/integration/
```

### Run Specific Integration Test

```bash
terraform test -filter=tests/integration/01_create_resources_complete.tftest.hcl
```

## E2E Tests (Disabled)

The integration test files contain commented-out `e2e_test` run blocks that would deploy actual infrastructure using `command = apply`. These are currently disabled due to Terraform test error handling limitations:

- **Issue:** [hashicorp/terraform#36846](https://github.com/hashicorp/terraform/issues/36846)
- **When to enable:** Once Terraform improves error handling and retry logic for test commands

## Test Workflow

Integration tests are automatically run by the `terraform-tests.yml` GitHub Actions workflow:

**Trigger Conditions:**

- Pull requests that modify files in `modules/**`
- Manual workflow dispatch

**Test Discovery:**

- Finds all modules with a `tests/` directory
- Runs `terraform test` from the module root

**Note:** Integration tests require AWS credentials configured in the CI environment via GitHub Secrets or OIDC authentication.

## Comparison with Unit Tests

| Aspect | Unit Tests | Integration Tests |
|--------|-----------|-------------------|
| **Speed** | Fast (seconds) | Slow (minutes) |
| **AWS Access** | Not required | Required |
| **Infrastructure** | Mock providers | Real AWS resources |
| **Purpose** | Test conditional logic | Test example deployments |
| **When to Run** | Every commit | Before releases |
| **Cost** | Free | AWS costs (minimal with plan-only) |

## Maintenance

### Adding New Integration Tests

1. Create a new `.tftest.hcl` file in this directory
2. Add required SSM parameters to `setup/ssm.tf`
3. Reference the appropriate example deployment
4. Update this README with test details

### Updating SSM Parameters

When test configuration changes:

1. Update SSM parameter values in your AWS account
2. Update `setup/ssm.tf` if new parameters are needed
3. Update integration test files to use new parameters

## Troubleshooting

### "Parameter not found" errors

- Verify SSM parameters exist in your AWS account
- Check parameter names match exactly (case-sensitive)
- Ensure AWS credentials have permission to read SSM parameters

### "Access denied" errors

- Verify your IAM role/user has required permissions
- Check that the AWS region is correct
- Ensure AWS credentials are properly configured

### Example not found errors

- Verify the example path is correct relative to module root
- Check that the example directory contains valid Terraform files
- Ensure you're running tests from the module root directory

## Related Documentation

- [Unit Tests](../unit/README.md) - Mock-based tests for conditional logic
- [Module Examples](../../examples/) - Example deployments referenced by tests
- [Main Module README](../../README.md) - Module usage and configuration
