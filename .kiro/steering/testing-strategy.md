# Terraform Testing Strategy

## Overview

All CGD Toolkit Terraform modules use the native `terraform test` framework with **mocked providers** to validate module logic without creating actual AWS resources.

## Key Principles

### Unit Tests Only
- Use `mock_provider` blocks to simulate AWS
- Test module logic, not AWS behavior
- No integration tests (Terraform test lacks cleanup functionality)

### Benefits
- **Zero AWS costs**: No resources created
- **No cleanup required**: No resources to clean up
- **No credentials needed**: Tests run without AWS authentication
- **Fast execution**: Tests complete in seconds
- **CI-ready**: Works in GitHub Actions without setup

## Test Structure

```hcl
# Mock AWS provider
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
}

mock_provider "random" {}

# Unit test
run "unit_test_scenario" {
  command = plan

  variables {
    vpc_id = "vpc-test123"
    # Test values directly in file
  }

  assert {
    condition     = length(aws_resource.main) > 0
    error_message = "Resource should be created"
  }
}
```

## What to Test

### ✅ Test (Module Logic)
- Variable validation logic
- Conditional resource creation
- Resource count calculations
- Dynamic block logic
- Local value computations
- Output expressions
- for_each and count logic

### ❌ Don't Test (AWS Behavior)
- Actual AWS resource creation
- AWS API functionality
- Network connectivity
- IAM permission validation in AWS
- Resource state after apply

## Running Tests

```bash
cd modules/{module-name}
terraform init
terraform test
```

## Test File Organization

```
modules/{module-name}/
├── tests/
│   ├── 01_basic.tftest.hcl      # Basic deployment
│   ├── 02_complete.tftest.hcl   # Full-featured deployment
│   ├── 03_feature.tftest.hcl    # Specific features
│   └── README.md                # Test documentation
```

## Writing Tests

1. **Mock all data sources** your module uses
2. **Duplicate mock providers in each test file** (Terraform limitation - cannot be shared)
3. **Test one scenario per run block**
4. **Use descriptive names** for runs and assertions
5. **Provide test values directly** in the test file
6. **Add clear assertions** with helpful error messages
7. **Test edge cases** (empty maps, null values, etc.)

### Mock Provider Duplication

Mock providers **must be duplicated** in each test file. This is a Terraform test framework limitation - mock providers cannot be shared across files or imported from modules. While this creates duplication, it ensures:
- Each test file is self-contained
- Tests can run independently
- No hidden dependencies between tests

## Example Test File

```hcl
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
}

mock_provider "random" {}

run "unit_test_basic_config" {
  command = plan

  variables {
    vpc_id = "vpc-12345678"
    create_external_alb = false
    create_internal_alb = true
  }

  assert {
    condition     = length(aws_lb.internal) == 1
    error_message = "Internal ALB should be created"
  }

  assert {
    condition     = length(aws_lb.external) == 0
    error_message = "External ALB should not be created"
  }
}
```

## CI/CD Integration

Tests run automatically in GitHub Actions on PRs. No AWS credentials or setup required.

## Integration Testing

For actual deployment validation:
- Use dedicated test environments
- Manual deployment and testing
- Proper cleanup procedures
- Not automated due to Terraform test limitations
