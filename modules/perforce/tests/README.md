# Perforce Module Tests

Mock-based unit tests for the Perforce wrapper module. All tests use mock providers and require no AWS credentials.

## Test Structure

```text
tests/
├── 01_conditional_creation.tftest.hcl  # Submodule conditional creation
├── 02_shared_resources.tftest.hcl      # Shared resource logic (ECS cluster, Route53, LBs)
└── README.md
```

## Running Tests

```bash
# From the module root
cd modules/perforce

# Run all tests
terraform test

# Run a specific test file
terraform test -filter=tests/02_shared_resources.tftest.hcl

# Verbose output
terraform test -verbose
```

## Adding New Tests

1. Create a new `.tftest.hcl` file in this directory
2. Copy mock provider blocks from an existing test file
3. Add test scenarios with descriptive names and clear assertion messages
4. Use `command = plan` for mock-based testing
