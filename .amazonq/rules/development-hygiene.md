# Development Hygiene Standards

## Documentation Requirements

### After Module Changes
**ALWAYS remind users to update documentation when making changes:**
- Update module `README.md` with new variables, outputs, or usage patterns
- Update examples if module interface changes
- Update any architectural diagrams if infrastructure changes
- Add changelog entries for significant changes

### New Module Creation
**REQUIRED documentation for new modules:**
- Comprehensive `README.md` with architecture diagrams
- Working examples in `examples/complete/`
- Variable descriptions and validation rules
- Output descriptions and usage guidance

## Git Workflow Standards

### Before Starting Work
**ALWAYS remind users to:**
```bash
# Pull latest changes from main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name
```

### Before Submitting PRs
**REQUIRED checks before PR submission:**
- Run `pre-commit run --all-files` to catch linting issues
- Ensure all Terraform files are formatted (`terraform fmt -recursive`)
- Run security scanning with Checkov
- Update documentation for any changes
- Test examples work with your changes

## Testing Requirements

### Terraform Testing
**For new modules, ALWAYS offer to help create:**
- Unit tests using Terratest or similar framework
- Integration tests for examples
- Validation tests for variable constraints

### Test Structure
**REQUIRED**: Organize tests with type prefix, number, and description:
```
tests/
├── setup/                                   # Shared test setup (REQUIRED)
│   ├── ssm.tf                              # SSM parameter retrieval
│   └── versions.tf                         # Test setup versions
├── unit_01_basic_single_region.tftest.hcl          # Unit test (plan only)
├── unit_02_basic_multi_region.tftest.hcl           # Unit test (plan only)
├── integration_01_single_region_deploy.tftest.hcl  # Integration/E2E test (apply)
└── integration_02_multi_region_deploy.tftest.hcl   # Integration/E2E test (apply)
```

**Naming Pattern**: `{number}_{description}.tftest.hcl`
- **Number**: `01`, `02`, etc. for execution order
- **Description**: Brief description of what the test covers (e.g., `basic_single_region`, `basic_multi_region`)

**Test Types:**
- **Unit Tests**: Use `command = plan` to validate configuration without deployment
- **Integration Tests**: Use `command = apply` for full deployment (apply + validate + destroy = E2E)

**Test Execution:**
```bash
# IMPORTANT: Run from module root directory (where tests/ directory is located)
cd /path/to/module  # Directory containing tests/ folder
terraform init      # Initialize from module root
terraform test      # Run all tests in numbered order

# Run specific test
terraform test -filter="01_basic_single_region.tftest.hcl"
```

**Common Test Issues:**
- **❌ Wrong directory**: Don't run from inside `tests/` directory
- **✅ Correct directory**: Run from module root (where `tests/` directory is located)
- **❌ No init**: Must run `terraform init` before `terraform test`
- **✅ Relative paths**: Test files use `./examples/` which only works from module root

### Test Setup Directory (REQUIRED)
**MANDATORY**: All modules must have a `tests/setup/` directory that retrieves test values from CI AWS account.

**Purpose**:
- Store test configuration values in AWS Systems Manager Parameter Store
- Avoid hardcoding sensitive or environment-specific values in test files
- Enable consistent testing across different environments

**Setup Structure:**
```hcl
# tests/setup/ssm.tf
data "aws_ssm_parameter" "route53_public_hosted_zone_name" {
  name = "/cgd-toolkit/tests/route53-public-hosted-zone-name"
}

data "aws_ssm_parameter" "ghcr_credentials_secret_arn" {
  name = "/cgd-toolkit/tests/ghcr-credentials-secret-arn"
}

output "route53_public_hosted_zone_name" {
  value = data.aws_ssm_parameter.route53_public_hosted_zone_name.value
}

output "ghcr_credentials_secret_arn" {
  value = data.aws_ssm_parameter.ghcr_credentials_secret_arn.value
}
```

**Parameter Requirements:**
- **CRITICAL**: Parameters must exist in CI AWS account before tests can run
- **Naming Convention**: `/cgd-toolkit/tests/{parameter-name}`
- **Validation**: Test parameter existence before creating tests
- **Documentation**: Document required parameters in module README

**Test Usage:**
```hcl
# tests/unit_01_basic_single_region.tftest.hcl
run "setup" {
  command = plan
  module {
    source = "./tests/setup"
  }
}

run "unit_test" {
  command = plan

  variables {
    route53_public_hosted_zone_name = run.setup.route53_public_hosted_zone_name
    ghcr_credentials_secret_arn = run.setup.ghcr_credentials_secret_arn
  }

  module {
    source = "./examples/single-region-basic"
  }
}
```

### Test Requirements
**REQUIRED**: Tests must reference examples and use setup directory:
- All tests in `tests/` directory must use `module.source = "./examples/[example-name]"`
- Tests must include setup run block to retrieve CI account parameters
- Tests validate common usage patterns through examples
- Both unit and integration tests are required for new modules
- **Parameter Validation**: Verify all required SSM parameters exist in CI account before test creation

### Example Testing Template
```hcl
# tests/01_basic_single_region.tftest.hcl
run "setup" {
  command = plan
  module {
    source = "./tests/setup"
  }
}

run "unit_test" {
  command = plan  # Unit tests use plan only

  variables {
    route53_public_hosted_zone_name = run.setup.route53_public_hosted_zone_name
  }

  module {
    source = "./examples/single-region-basic"  # Always reference examples
  }
}

# Integration test (currently disabled due to Terraform test limitations)
# run "integration_test" {
#   command = apply
#   module {
#     source = "./examples/single-region-basic"
#   }
# }
```

## Security Scanning

### Checkov Integration
**ALWAYS offer to run security scans:**
- Use Checkov tool to scan Terraform code for security issues
- Help resolve security findings before PR submission
- Explain security implications of any findings

### Security Scan Workflow
```bash
# Offer to run these commands for users
checkov -d . --framework terraform
checkov -d . --framework terraform --check CKV_AWS_*
```

### Common Security Reminders
- No hardcoded secrets in code
- Use least privilege IAM policies
- Ensure security groups don't allow 0.0.0.0/0 ingress
- Use encryption at rest and in transit
- Follow CGD Toolkit security patterns

## Code Quality Standards

### Pre-commit Hooks
**ALWAYS remind users to run:**
```bash
# Install pre-commit hooks
pre-commit install

# Run on all files
pre-commit run --all-files
```

### Terraform Formatting
**REQUIRED before committing:**
```bash
terraform fmt -recursive
terraform validate
```

### Linting Standards
- Use `tflint` for Terraform-specific linting
- Follow consistent naming conventions
- Use meaningful resource names and descriptions
- Add appropriate tags to all resources

## Automation Reminders

### When to Offer Help
**Automatically offer to help with:**
- Creating Terraform tests for new modules
- Setting up pre-commit hooks for new contributors
- Running security scans before PR submission
- Generating documentation templates
- Creating example configurations

### Proactive Suggestions
**After completing module work, ALWAYS ask:**
- "Would you like me to help create Terraform tests for this module?"
- "Should I run a security scan with Checkov to check for issues?"
- "Do you need help updating the documentation?"
- "Would you like me to create an example configuration?"
- "Do you need help setting up the tests/setup/ directory with SSM parameter retrieval?"
- "Should I help you identify which SSM parameters need to be created in the CI account?"
- "Would you like me to implement centralized logging following the CGD Toolkit standards?"

## Centralized Logging Implementation
**ALWAYS offer to implement standardized logging when working on modules:**
- Follow the centralized logging pattern from cgd-toolkit-design.md
- Use infrastructure/, application/, service/ structure
- Create CloudWatch Log Groups with descriptive tags
- Set up proper S3 bucket permissions for all AWS services
- Include standard logging variables (enable_centralized_logging, log_retention_days)
- Ensure future-ready structure with empty log groups for planned services

### Critical Gap: Log Shipping Configuration
**IMPORTANT**: Creating CloudWatch log groups ≠ logs actually being sent. Most modules only create log destinations but don't configure log sources:

**✅ Usually Configured:**
- NLB/ALB access logs → S3 (automatic via load balancer configuration)
- EKS pod metrics → CloudWatch (via Container Insights)

**❌ Usually Missing:**
- **Application logs** → CloudWatch (requires container logging configuration)
- **Database logs** (ScyllaDB, RDS) → CloudWatch (requires log shipping setup)
- **EKS control plane logs** → CloudWatch (requires EKS cluster logging enablement)
- **Custom service logs** → CloudWatch (requires log agent/shipping configuration)

**When implementing logging, ensure both:**
1. **Log destinations** (CloudWatch log groups, S3 buckets)
2. **Log sources** (actual configuration to ship logs to destinations)

- **Note**: DDC application metrics (cache hit rates, response times) require application-level configuration and are not currently implemented in CGD Toolkit modules

## Parent Module README Standards

### Essential Sections (Must Have)

1. **Header with Service Warning** - Title, license, critical access warnings
2. **Version Requirements** - Terraform/provider versions with explanations
3. **Features** - Key capabilities bullet list
4. **Architecture** - Diagrams (single + multi-region), component explanations
5. **Prerequisites** - Tools, access, network requirements, service-specific setup
6. **Examples** - Links to examples directory with available types
7. **Deployment Instructions** - Step-by-step process with commands
8. **Verification & Testing** - Basic checks and connectivity tests
9. **Client Connection Guide** - End-user setup (UE, Jenkins, etc.)
10. **Troubleshooting** - Common issues, solutions, debugging commands
11. **Auto-Generated Docs** - terraform-docs tables

### Standard Sections (Should Have)

12. **User Personas** - DevOps vs End Users with access requirements
13. **Deployment Patterns** - Single vs multi-region guidance
14. **Security & Access Patterns** - Network architecture, access methods
15. **Best Practices** - Security, performance, operations guidelines

### Optional Sections (Nice to Have)

16. **Multi-Region Considerations** - DNS strategies, regional requirements (if applicable)
17. **Advanced Configuration** - Complex setups, build farm integration
18. **Migration Guide** - Upgrade procedures, breaking changes

### Section Ordering Rules

- **Critical info first** - Warnings, versions, prerequisites
- **Implementation flow** - Architecture → Prerequisites → Deployment → Testing
- **User guidance** - Connection setup → Troubleshooting → Best practices
- **Reference material last** - Auto-generated docs at bottom

### Content Guidelines

- **Service-specific warnings** prominently displayed
- **Step-by-step commands** with copy-paste examples
- **Regional DNS patterns** (us-east-1.service.example.com)
- **Access method control** (external/internal patterns)
- **Security validation** (no 0.0.0.0/0 examples)

**This structure ensures consistency across all CGD Toolkit parent modules while allowing service-specific customization.**

## Submodule README Standards

### Essential Sections (Must Have)

1. **Service Introduction** - Brief description with link to official docs, what the submodule creates
2. **Architecture** - Architecture diagram (if available)
3. **Prerequisites** - Required setup steps (AMIs, secrets, dependencies)
4. **Configuration** - Key variables and usage examples
5. **Auto-Generated Docs** - terraform-docs tables

### Optional Sections (If Applicable)

6. **Optional Configuration** - Additional configurations with examples

### Content Guidelines

- **High-level overview only** - Link to official docs for complex applications (ScyllaDB, Unreal Cloud DDC, etc.)
- **Focus on integration** - How the submodule fits with parent module, not application expertise
- **Prerequisites prominent** - Critical setup steps clearly visible
- **Configuration examples** - Show how to use the submodule
- **Avoid duplication** - Don't replicate official application documentation

### Template Structure

```markdown
# [Submodule Name]

[Brief service description with link to official docs]

[What this submodule creates/provisions - 2-3 sentences]

## Architecture
[Architecture diagram if available]

## Prerequisites
[Required setup steps - AMIs, secrets, dependencies]

### Optional
[Optional configurations with examples]

## Configuration
[Key variables and usage examples]

## [Auto-generated terraform-docs content]
```

**Goal: Provide integration guidance, not application expertise. Link to official docs for complex applications.**
