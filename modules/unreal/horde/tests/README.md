# Horde Module Tests

This directory contains Terraform unit tests for the Unreal Engine Horde module using **mocked providers**.

## Overview

Tests use `mock_provider` blocks to validate module logic without making actual AWS API calls or creating resources. This approach provides:

- **Zero AWS costs**: No resources created
- **Fast execution**: Tests run in seconds
- **No cleanup required**: No resources to clean up
- **No credentials needed**: Tests run without AWS authentication
- **Logic validation**: Focus on module conditionals, variable validation, and resource configuration

## Test Files

- `01_basic.tftest.hcl` - Basic deployment with minimal configuration
- `02_complete.tftest.hcl` - Complete deployment with all features
- `03_auth_methods.tftest.hcl` - Authentication method configurations
- `04_agents.tftest.hcl` - Build agent configurations

## Running Tests

### Locally

```bash
# From the horde module directory
cd modules/unreal/horde

# Initialize (downloads providers)
terraform init

# Run all tests
terraform test

# Run specific test
terraform test -filter=tests/01_basic.tftest.hcl

# Verbose output
terraform test -verbose

# Skip initialization for faster iteration
terraform test -no-init
```

### In CI

Tests run automatically on pull requests that modify the Horde module. The CI workflow:

1. Detects changes to `modules/unreal/horde/**`
2. Runs `terraform init`
3. Runs `terraform test -verbose`
4. Reports results on the PR

**No AWS credentials required** - mocked providers eliminate the need for authentication.

## What Gets Tested

### ✅ Module Logic (What We Test)

- **Variable validation**: Validation rules trigger correctly
- **Conditional resource creation**: Resources created/skipped based on variables
- **Resource counts**: Correct number of resources based on configuration
- **Dynamic blocks**: Dynamic blocks generate expected configuration
- **for_each logic**: Loops create expected resource instances
- **count logic**: Count expressions evaluate correctly
- **Dependency chains**: Resources reference each other correctly

### ❌ AWS Behavior (What We Don't Test)

- Actual resource creation in AWS
- AWS API functionality
- Network connectivity
- IAM permission validation
- Resource state after apply
- Real DNS resolution
- Certificate validation

## Test Scenarios

### 01_basic.tftest.hcl

Tests minimal deployment configuration:

- Internal ALB only
- Default DocumentDB and ElastiCache settings
- No authentication
- No build agents

**Key Assertions**:

- ECS cluster and service created
- Internal ALB created, external ALB not created
- DocumentDB and ElastiCache clusters created
- Security groups and IAM roles created

### 02_complete.tftest.hcl

Tests full-featured deployment:

- External and internal ALBs
- Custom database and cache configurations
- ALB access logging
- All optional features enabled

**Key Assertions**:

- Both ALBs created with target groups
- Custom DocumentDB instance count (3)
- Valkey cache engine
- S3 bucket for ALB logs
- Security groups for both ALBs

### 03_auth_methods.tftest.hcl

Tests authentication configurations:

- Anonymous authentication
- OIDC authentication
- Okta authentication
- Perforce integration
- Variable validation for auth methods

**Key Assertions**:

- Valid auth methods work
- Invalid auth methods fail validation
- OIDC requires all parameters
- Perforce integration configures correctly

### 04_agents.tftest.hcl

Tests build agent configurations:

- Single agent pool
- Multiple agent pools
- No agents configured
- Custom dotnet runtime versions

**Key Assertions**:

- Correct number of ASGs and launch templates
- S3 bucket created when agents configured
- No resources when agents map is empty
- Custom configurations applied correctly

## Mocked Providers

All test files use identical `mock_provider` blocks to simulate AWS and random providers. While this creates duplication across test files, it's required by the Terraform test framework - mock providers cannot be shared or imported.

### Standard Mock Configuration

Each test file includes these mocks:

```hcl
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
      id   = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDACKCEVSQ6C2EXAMPLE"
    }
  }

  mock_data "aws_elb_service_account" {
    defaults = {
      arn = "arn:aws:iam::127311923021:root"
      id  = "127311923021"
    }
  }

  mock_data "aws_ecs_cluster" {
    defaults = {
      arn                = "arn:aws:ecs:us-east-1:123456789012:cluster/test"
      id                 = "test"
      name               = "test"
      status             = "ACTIVE"
      pending_tasks_count = 0
      running_tasks_count = 0
    }
  }
}

mock_provider "random" {}
```

### Why Duplication is Necessary

- **Terraform limitation**: Mock providers cannot be shared across test files
- **Self-contained tests**: Each test file must be independently runnable
- **Framework requirement**: Mock providers must be defined in the same file as the tests

### Benefits

This approach eliminates the need for:

- AWS credentials
- SSM Parameter Store
- Actual AWS resources
- Resource cleanup

## Adding New Tests

1. Create a new `.tftest.hcl` file following the naming convention
2. Add `mock_provider` blocks for AWS and random providers
3. Add `run` blocks with `command = plan`
4. Provide test values directly in variables
5. Add assertions for critical behavior

Example:

```hcl
mock_provider "aws" {
  # Mock data sources
}

mock_provider "random" {}

run "unit_test_feature" {
  command = plan

  variables {
    vpc_id = "vpc-test123"
    # ... other variables
  }

  assert {
    condition     = length(aws_resource.main) > 0
    error_message = "Resource should be created"
  }
}
```

## Troubleshooting

### Tests fail with "data source not found"

**Cause**: Module uses a data source that isn't mocked
**Solution**: Add the data source to the `mock_provider` block

### Variable validation errors

**Cause**: Test values don't meet validation rules
**Solution**: Check validation rules in `variables.tf` and adjust test values

### Assertion failures

**Cause**: Module logic doesn't match expected behavior
**Solution**: Review module code or adjust assertions

## Best Practices

1. **Test logic, not AWS**: Focus on conditionals, counts, and variable validation
2. **Use descriptive assertions**: Clear error messages help debugging
3. **Test edge cases**: Empty maps, null values, boundary conditions
4. **Keep tests fast**: Mocked providers ensure tests run in seconds
5. **One scenario per run block**: Makes failures easier to diagnose

## Integration Testing

Integration tests (using `terraform apply`) are **not implemented** due to Terraform test framework limitations:

- No automatic cleanup functionality
- Resource cleanup must be manual
- Risk of orphaned resources

For integration testing:

- Use dedicated test environments
- Manual deployment and validation
- Proper cleanup procedures

## References

- [Terraform Test Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Mock Providers](https://developer.hashicorp.com/terraform/language/tests/mocking)
- [CGD Toolkit Design Standards](../../../DESIGN_STANDARDS.md)
