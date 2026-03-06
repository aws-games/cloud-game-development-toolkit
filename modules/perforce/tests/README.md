# Perforce Module Tests

This directory contains comprehensive tests for the Perforce wrapper module, organized into unit tests and integration tests.

## Test Structure

```text
tests/
├── unit/                                    # Mock-based unit tests
│   ├── 01_conditional_creation.tftest.hcl   # Tests submodule conditional creation
│   ├── 02_shared_resources.tftest.hcl       # Tests shared resource logic
│   └── README.md                            # Unit test documentation
│
├── integration/                             # Integration tests with real AWS
│   ├── setup/                               # Setup module for SSM parameters
│   │   ├── ssm.tf                          # SSM parameter data sources
│   │   └── versions.tf                     # Provider requirements
│   ├── 01_create_resources_complete.tftest.hcl
│   ├── 02_p4_server_fsxn.tftest.hcl
│   └── README.md                            # Integration test documentation
│
└── README.md                                # This file
```

## Quick Start

### Run All Tests

```bash
cd /path/to/modules/perforce
terraform test
```

### Run Only Unit Tests (No AWS Required)

```bash
terraform test -filter=tests/unit/
```

### Run Only Integration Tests (AWS Required)

```bash
export AWS_PROFILE=your-profile
terraform test -filter=tests/integration/
```

## Test Types

### Unit Tests (`unit/`)

**Purpose:** Validate conditional logic and resource creation without deploying infrastructure

**Characteristics:**

- ✅ Uses mock providers (no AWS credentials needed)
- ✅ Fast execution (seconds)
- ✅ Safe to run anywhere
- ✅ Tests all conditional logic paths
- ✅ No AWS costs

**When to Run:** On every code change, in CI/CD pipelines, during development

**Test Coverage:**

- Conditional creation of P4 Server, P4 Auth, and P4 Code Review submodules
- Shared ECS cluster creation logic
- Load balancer and Route53 resource creation
- Security group configurations

[📖 Unit Tests Documentation](unit/README.md)

### Integration Tests (`integration/`)

**Purpose:** Validate that example deployments work with real AWS resources

**Characteristics:**

- ⚠️ Requires AWS credentials
- ⚠️ Slower execution (minutes)
- ⚠️ Plans against real AWS (no apply by default)
- ✅ Tests real-world scenarios
- ✅ Validates examples work correctly

**When to Run:** Before releases, when testing infrastructure changes, in CI/CD with AWS access

**Test Coverage:**

- Complete Perforce deployment example
- P4 Server with FSxN storage example
- Example configurations with real parameters

[📖 Integration Tests Documentation](integration/README.md)

## CI/CD Integration

### Validation Workflow

The `terraform-validation.yml` workflow validates Terraform configurations:

**What it validates:**

- All directories containing `.tf` files (modules, submodules, examples, test setup)
- Runs `terraform init` and `terraform validate`
- Skips directories with only `.tftest.hcl` files

**What triggers it:**

- Changes to `modules/**/*.tf` or `samples/**/*.tf`
- Push to `main` branch
- Manual workflow dispatch

### Test Workflow

The `terraform-tests.yml` workflow runs Terraform tests:

**What it runs:**

- All `.tftest.hcl` files in modules with a `tests/` directory
- Automatically runs when module files change
- Requires AWS credentials for integration tests

**Workflow behavior:**

- Detects changed modules
- Runs `terraform test` from module root
- Reports failures to pull requests

## Development Workflow

### Adding New Features

1. **Write unit tests first** - Add test scenarios to `unit/` for new conditional logic
2. **Implement the feature** - Modify module code
3. **Run unit tests** - Verify conditional logic works: `terraform test -filter=tests/unit/`
4. **Add integration tests** - If needed, add scenarios to `integration/`
5. **Run all tests** - Verify everything works: `terraform test`

### Debugging Test Failures

**Unit test failures:**

```bash
# Run with verbose output
terraform test -filter=tests/unit/01_conditional_creation.tftest.hcl -verbose

# Check specific assertion
# Look for "error_message" in the output to see which assertion failed
```

**Integration test failures:**

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check SSM parameters exist
aws ssm get-parameter --name "/cloud-game-development-toolkit/modules/perforce/route53-public-hosted-zone-name"

# Run with verbose output
terraform test -filter=tests/integration/ -verbose
```

## Test Maintenance

### When to Update Tests

**Update unit tests when:**

- Adding new conditional logic
- Adding new submodules or shared resources
- Changing variable validation rules
- Modifying resource creation conditions

**Update integration tests when:**

- Adding new examples
- Changing example configurations
- Modifying required variables
- Adding new deployment patterns

### Adding New Test Files

**Unit tests:**

1. Create new `.tftest.hcl` file in `unit/`
2. Copy mock provider blocks from existing test
3. Add test scenarios with clear names and assertions
4. Update `unit/README.md` with test documentation

**Integration tests:**

1. Create new `.tftest.hcl` file in `integration/`
2. Add required SSM parameters to `integration/setup/ssm.tf`
3. Reference appropriate example deployment
4. Update `integration/README.md` with test documentation

## Best Practices

### Writing Good Tests

✅ **DO:**

- Use descriptive test names (`p4_server_only` not `test1`)
- Write clear assertion error messages
- Test both success and failure scenarios
- Document complex test logic with comments
- Keep tests focused on one aspect

❌ **DON'T:**

- Hardcode sensitive values (use SSM for integration tests)
- Create tests that depend on execution order
- Test implementation details (test behavior, not code)
- Ignore test failures (fix or document expected failures)

### Mock Provider Patterns

When creating unit tests:

1. Always include all mock providers (even if unused)
2. Use realistic mock data (valid ARNs, IDs, etc.)
3. Copy mock blocks from existing tests for consistency
4. Document any custom mock configurations

## Performance Considerations

### Test Execution Time

| Test Type | Typical Duration | Parallelization |
|-----------|-----------------|-----------------|
| Unit (single file) | 2-5 seconds | Yes |
| Unit (all) | 10-15 seconds | Yes |
| Integration (single) | 30-60 seconds | Yes |
| Integration (all) | 2-5 minutes | Yes |

### Optimizing Test Speed

- Run unit tests during development (fast feedback)
- Run integration tests before commits (thorough validation)
- Use `-filter` to run specific tests during debugging
- Leverage Terraform's parallel test execution

## Troubleshooting

### Common Issues

#### "No tests found"

- Ensure you're running from the module root directory
- Verify `.tftest.hcl` files exist in `tests/` subdirectories

#### "Module not found"

- Check that module paths are relative to the test file location
- Integration tests should use `../../examples/` for example paths
- Unit tests should reference the module root

#### "Provider configuration not found"

- Verify all required mock providers are declared
- Check that provider versions match `versions.tf`

#### "Variable not set"

- Ensure all required variables are provided in test scenarios
- Check that variable types match module expectations

## Additional Resources

- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Module README](../README.md)
- [Example Deployments](../examples/)
- [Horde Module Tests](../../unreal/horde/tests/) - Reference implementation

## Contributing

When contributing tests:

1. Follow existing test patterns and naming conventions
2. Update documentation when adding new tests
3. Ensure tests pass locally before submitting PR
4. Add test coverage for new features
5. Keep tests maintainable and well-documented

## Questions?

For questions about testing:

- Review the [unit test README](unit/README.md) for mock-based testing
- Review the [integration test README](integration/README.md) for AWS-based testing
- Check the [main module documentation](../README.md) for module usage
- Open an issue in the repository for specific problems
