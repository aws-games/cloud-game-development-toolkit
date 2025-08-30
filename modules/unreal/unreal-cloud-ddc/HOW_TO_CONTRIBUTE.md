# How to Contribute to Cloud Game Development Toolkit

## Documentation Standards

### Module Documentation Structure

All modules should follow this standardized README structure:

```markdown
# Module Name

Brief description of what the module does and its primary use case.

## Architecture

### Overview
High-level architecture diagram and explanation.

### Components
- **Component 1**: What it does, why it's needed
- **Component 2**: What it does, why it's needed

## Prerequisites

### Required Tools & Access
- Tool requirements with version constraints
- AWS permissions needed
- External dependencies

### Critical Requirements
- IP access requirements
- Network dependencies
- Service limits

## Usage

### Basic Example
Simple, working example that users can copy-paste.

### Advanced Configuration
More complex examples with explanations.

## Configuration

### Variables
Document all variables with:
- Purpose and impact
- Default values and reasoning
- Validation rules and constraints
- Examples of common values

### Outputs
Document all outputs with:
- What they represent
- When to use them
- Integration examples

## Multi-Region Deployment (if applicable)

### Architecture Patterns
- Single vs multi-region considerations
- Data replication strategies
- Failover mechanisms

### Deployment Process
Step-by-step multi-region deployment guide.

## Automatic Cleanup Configuration (if applicable)

### Options Available
- Automatic vs manual cleanup
- Trade-offs and recommendations
- Configuration examples

## Troubleshooting

### Creation Issues
Common deployment failures with:
- Symptoms
- Root causes
- Step-by-step solutions
- Prevention strategies

### Update Issues
Common update problems and solutions.

### Connection Issues
Network, authentication, and access problems.

### Deletion Issues
Destroy failures and cleanup procedures.

### Common Configuration Issues
Misconfigurations and fixes.

## Frequently Asked Questions (FAQ)

### Architecture & Components
Technical questions about design decisions.

### Configuration & Customization
How to modify and extend the module.

### Deployment & Operations
Operational questions and best practices.

### Troubleshooting
Quick answers to common problems.

## Getting Help
Links to support resources.
```

### Documentation Quality Standards

#### **Clarity & Completeness**
- **Assume no prior knowledge** of the specific service
- **Explain technical terms** on first use
- **Provide context** for design decisions
- **Include real examples** with dummy data
- **Cross-reference** related concepts

#### **Structure & Organization**
- **Logical flow**: Prerequisites → Usage → Configuration → Troubleshooting
- **Consistent headings**: Use standardized section names
- **Scannable content**: Bullet points, tables, code blocks
- **Progressive detail**: Overview → specifics → edge cases

#### **Code Examples**
- **Complete and runnable**: Include all required variables
- **Commented**: Explain non-obvious configurations
- **Realistic**: Use plausible values, not placeholder text
- **Multiple scenarios**: Basic, advanced, multi-region examples

#### **Troubleshooting Guidelines**
- **Symptom-based organization**: Start with what users see
- **Root cause analysis**: Explain why problems occur
- **Step-by-step solutions**: Actionable commands and procedures
- **Prevention advice**: How to avoid issues

### Design Decision Documentation

#### **Architecture Decisions**
Document major architectural choices:
- **What**: The decision made
- **Why**: Reasoning and trade-offs considered
- **Alternatives**: Options rejected and why
- **Impact**: Implications for users
- **Future**: Potential changes or improvements

#### **Technology Choices**
Explain technology selections:
- **Performance requirements**: Why specific tools were chosen
- **Integration needs**: How components work together
- **Operational considerations**: Management and maintenance impact
- **Cost implications**: Resource usage and pricing impact

#### **Multi-Region Patterns**
For multi-region modules:
- **Deployment patterns**: Single instance vs multiple instances
- **Data consistency**: Replication strategies and trade-offs
- **Failover mechanisms**: How high availability is achieved
- **Network architecture**: Cross-region connectivity patterns

### FAQ Development Process

#### **Question Sources**
- **User feedback**: GitHub issues and discussions
- **Support requests**: Common help requests
- **Design reviews**: Questions raised during development
- **Testing**: Issues discovered during validation

#### **Answer Quality**
- **Comprehensive**: Cover the full scope of the question
- **Actionable**: Provide specific steps or examples
- **Contextual**: Explain why, not just how
- **Updated**: Keep answers current with module changes

### Module Consistency Standards

#### **Naming Conventions**
- **Variables**: Use consistent naming patterns across modules
- **Resources**: Follow standardized resource naming
- **Outputs**: Provide similar outputs for similar functionality
- **Tags**: Use consistent tagging strategies

#### **Configuration Patterns**
- **Optional vs Required**: Consistent approach to variable defaults
- **Validation**: Similar validation patterns and error messages
- **Documentation**: Consistent variable descriptions and examples

#### **Multi-Region Support**
- **Deployment patterns**: Use consistent multi-region approaches
- **Variable structure**: Similar configuration objects across modules
- **Cleanup mechanisms**: Consistent cleanup strategies
- **Documentation**: Similar multi-region documentation structure

### Review Process

#### **Documentation Reviews**
- **Technical accuracy**: Verify all technical details
- **Completeness**: Ensure all features are documented
- **Clarity**: Test with users unfamiliar with the module
- **Consistency**: Check against other module documentation

#### **Example Validation**
- **Test all examples**: Ensure code examples actually work
- **Validate commands**: Test all CLI commands and scripts
- **Check links**: Verify all external links are functional
- **Update regularly**: Keep examples current with module changes

### Continuous Improvement

#### **User Feedback Integration**
- **Monitor issues**: Track common questions and problems
- **Update documentation**: Address recurring confusion
- **Expand examples**: Add examples for common use cases
- **Improve troubleshooting**: Add solutions for new problems

#### **Module Evolution**
- **Document changes**: Update docs with new features
- **Deprecation notices**: Clearly mark deprecated features
- **Migration guides**: Provide upgrade instructions
- **Backward compatibility**: Document breaking changes

## Module Structure Standards

### Directory Structure

#### **Simple Module (No Submodules)**
Use when module has single, cohesive functionality:

```
modules/service-name/
├── README.md                    # Module documentation
├── HOW_TO_CONTRIBUTE.md        # Contribution guidelines
├── main.tf                     # Primary resources
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
├── locals.tf                   # Local values and computations
├── versions.tf                 # Provider version constraints
├── data.tf                     # Data sources (optional)
├── assets/                     # Supporting files
│   ├── scripts/               # Shell scripts, utilities
│   ├── configs/               # Configuration templates
│   └── media/                 # Documentation images
└── examples/                   # Usage examples
    ├── basic/                 # Simple deployment example
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars.example
    │   └── README.md
    └── advanced/              # Complex deployment example
        ├── main.tf
        ├── variables.tf
        ├── terraform.tfvars.example
        └── README.md
```

**When to use**: Single AWS service, simple configuration, no complex interdependencies.

**Examples**: S3 bucket module, Lambda function module, single RDS instance.

#### **Complex Module (With Submodules)**
Use when module orchestrates multiple related services:

```
modules/service-name/
├── README.md                    # Parent module documentation
├── HOW_TO_CONTRIBUTE.md        # Contribution guidelines
├── main.tf                     # Submodule orchestration
├── variables.tf                # Parent module variables
├── outputs.tf                  # Aggregated outputs
├── locals.tf                   # Shared computations
├── versions.tf                 # Provider constraints
├── assets/                     # Parent module assets
│   ├── media/
│   │   └── diagrams/          # Architecture diagrams
│   └── submodules/            # Submodule-specific assets
│       ├── component-1/       # Assets for first submodule
│       ├── component-2/       # Assets for second submodule
│       └── component-3/       # Assets for third submodule
├── modules/                    # Submodules directory
│   ├── component-1/           # First logical component
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── locals.tf
│   ├── component-2/           # Second logical component
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── locals.tf
│   └── component-3/           # Third logical component
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── locals.tf
└── examples/                   # Complete deployment examples
    ├── single-region/         # Single region deployment
    │   ├── assets/
    │   │   └── scripts/       # Example-specific scripts
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars.example
    │   └── README.md
    └── multi-region/          # Multi-region deployment
        ├── assets/
        │   └── scripts/       # Example-specific scripts
        ├── main.tf
        ├── variables.tf
        ├── terraform.tfvars.example
        └── README.md
```

**When to use**: Multiple AWS services, complex interactions, logical separation of concerns.

**Examples**: Unreal Cloud DDC (EKS + ScyllaDB + Monitoring), Game Backend (API Gateway + Lambda + RDS + ElastiCache).

### File Naming Conventions

#### **Core Terraform Files**
- `main.tf` - Primary resource definitions
- `variables.tf` - Input variable declarations
- `outputs.tf` - Output value definitions
- `locals.tf` - Local value computations
- `versions.tf` - Provider version constraints
- `data.tf` - Data source queries (optional)

#### **Specialized Files**
- `security.tf` - Security groups, IAM roles, policies
- `networking.tf` - VPC, subnets, routing (if module creates networking)
- `monitoring.tf` - CloudWatch, alarms, dashboards
- `dns.tf` - Route53 records and zones
- `storage.tf` - S3, EBS, EFS resources
- `compute.tf` - EC2, EKS, Lambda resources

#### **Asset Organization**
```
assets/
├── media/
│   ├── diagrams/              # Architecture diagrams (.png, .svg)
│   ├── screenshots/           # UI screenshots
│   └── images/               # Other documentation images
├── scripts/                   # Utility scripts
│   ├── setup.sh             # Environment setup
│   ├── test.sh               # Testing scripts
│   └── cleanup.sh            # Manual cleanup procedures
├── configs/                   # Configuration templates
│   ├── app-config.yaml.tpl  # Application configuration templates
│   └── nginx.conf.tpl        # Service configuration templates
└── submodules/               # Submodule-specific assets (complex modules only)
    ├── component-1/
    ├── component-2/
    └── component-3/
```

### Module Design Principles

#### **When to Use Simple Module**
- **Single responsibility**: Module manages one AWS service or tightly related group
- **Minimal complexity**: Straightforward configuration with few interdependencies
- **Reusable component**: Designed to be consumed by other modules
- **Clear boundaries**: Well-defined inputs and outputs

**Examples**:
- S3 bucket with lifecycle policies
- Lambda function with IAM role
- RDS instance with parameter group
- CloudFront distribution

#### **When to Use Complex Module (Submodules)**
- **Multiple services**: Orchestrates several AWS services working together
- **Complex interactions**: Services have intricate dependencies and data flow
- **Logical separation**: Different components serve distinct purposes
- **Independent lifecycle**: Components may be deployed/updated separately
- **Conditional deployment**: Some components are optional based on configuration

**Examples**:
- **Game Backend**: API Gateway + Lambda + RDS + ElastiCache + CloudFront
- **CI/CD Pipeline**: CodeCommit + CodeBuild + CodePipeline + S3 + CloudFormation
- **Monitoring Stack**: EKS + Prometheus + Grafana + AlertManager + S3
- **Data Platform**: Kinesis + Lambda + S3 + Glue + Athena + QuickSight

#### **Submodule Design Guidelines**
- **Logical boundaries**: Each submodule represents a distinct functional component
- **Minimal coupling**: Submodules should have minimal dependencies on each other
- **Clear interfaces**: Well-defined inputs and outputs between submodules
- **Independent testing**: Each submodule should be testable in isolation
- **Conditional inclusion**: Parent module should support optional submodules

**Unreal Cloud DDC Example**:
```hcl
# Parent module orchestrates three logical components:
module "ddc_infra" {        # Infrastructure: EKS, ScyllaDB, NLB
  source = "./modules/ddc-infra"
  count  = var.ddc_infra_config != null ? 1 : 0
}

module "ddc_monitoring" {    # Monitoring: Grafana, Prometheus
  source = "./modules/ddc-monitoring"
  count  = var.ddc_monitoring_config != null ? 1 : 0
}

module "ddc_services" {      # Applications: Helm charts
  source = "./modules/ddc-services"
  count  = var.ddc_services_config != null ? 1 : 0
}
```

## Code Standards

### Terraform Best Practices
- Use consistent variable naming and descriptions
- Implement proper validation rules
- Provide meaningful outputs
- Follow security best practices

### Terraform Testing Framework

#### Test Structure
All modules should include Terraform tests that validate examples/samples:

```
modules/service-name/
├── tests/
│   ├── setup/                    # Test setup and shared resources
│   │   ├── ssm.tf               # SSM parameters for test data
│   │   └── versions.tf          # Provider versions
│   ├── 01_basic.tftest.hcl      # Tests examples/basic/ or samples/basic/
│   ├── 02_advanced.tftest.hcl   # Tests examples/advanced/ or samples/advanced/
│   └── 03_multi_region.tftest.hcl # Tests examples/multi-region/ or samples/multi-region/
└── examples/ (or samples/)
    ├── basic/                   # Basic deployment example
    ├── advanced/                # Advanced configuration example
    └── multi-region/            # Multi-region deployment example
```

**Test Naming Rules:**
1. **Numbered prefix** (01, 02, 03...) for execution order
2. **Match example/sample name** exactly after the number
3. **One test per example/sample** directory

**See the Perforce module for a real implementation example.**

#### Test Implementation (Perforce Module Pattern)
**Tests validate examples/samples by running `terraform plan` against them:**

```hcl
# tests/01_basic.tftest.hcl
# Fetch relevant values from SSM Parameter Store
run "setup" {
  command = plan
  module {
    source = "./tests/setup"
  }
}

run "unit_test" {
  command = plan

  variables {
    # Use values from setup
    route53_public_hosted_zone_name = run.setup.route53_public_hosted_zone_name
  }
  module {
    source = "./examples/basic"  # Test the corresponding example
  }
}

# E2E tests commented out until Terraform test retry logic improves
# run "e2e_test" {
#   command = apply
#   module {
#     source = "./examples/basic"
#   }
# }
```

**Minimum Required Tests:**
- **One test per example/sample** (e.g., `01_basic.tftest.hcl` tests `examples/basic/`)
- **Tests run `terraform plan`** to validate configuration
- **Setup module** provides shared test data from SSM
- **Numbered naming** (01, 02, 03...) + exact example/sample name

**Advanced Tests (Optional):**
You can add more sophisticated tests with assertions and apply operations, but the **minimum requirement** is plan-based validation of examples.

#### Examples vs Tests vs Samples

**Examples** (`examples/`):
- **Purpose**: User-facing documentation and tutorials
- **Audience**: End users learning how to use the module
- **Content**: Complete, working configurations with explanatory README files
- **Maintenance**: Must always work with current module version
- **Location**: `examples/basic/`, `examples/advanced/`, `examples/multi-region/`

**Tests** (`tests/`):
- **Purpose**: Automated validation of module functionality
- **Audience**: Developers and CI/CD systems
- **Content**: Comprehensive test scenarios including edge cases
- **Maintenance**: Run automatically on every PR
- **Location**: `tests/unit/`, `tests/integration/`

**Samples** (Legacy - being phased out):
- **Purpose**: Quick reference implementations (deprecated pattern)
- **Migration**: Move to `examples/` with proper documentation
- **Reason**: "Samples" implies incomplete/reference-only, "Examples" implies working tutorials

#### Test Requirements
- **All modules MUST include tests** before merging
- **Tests must cover**:
  - Basic deployment scenarios
  - Advanced configuration options
  - Multi-region deployments (if applicable)
  - Cleanup and destroy operations
  - Variable validation and error conditions
- **Tests must pass** in CI/CD pipeline before PR approval
- **Examples must be tested** to ensure they work as documented

#### Learning Resources
- **Blog**: [Terraform CI/CD and Testing on AWS](https://aws.amazon.com/blogs/devops/terraform-ci-cd-and-testing-on-aws-with-the-new-terraform-test-framework/)
- **Workshop**: [Terraform CI/CD on AWS Workshop](https://catalog.workshops.aws/terraform-cicd-on-aws/en-US)
- **Documentation**: [Terraform Test Framework](https://developer.hashicorp.com/terraform/language/tests)

### Testing Requirements
- Validate all examples work as documented
- Test multi-region scenarios
- Verify cleanup procedures
- Test edge cases and error conditions
- **PRs with failing tests will NOT be merged**

## Contribution Workflow

### Fork-First Development Model

1. **Fork the Repository**:
   ```bash
   # Fork aws-games/cloud-game-development-toolkit on GitHub
   git clone https://github.com/YOUR_USERNAME/cloud-game-development-toolkit.git
   cd cloud-game-development-toolkit
   ```

2. **Create Feature Branch**:
   ```bash
   git checkout -b feature/your-module-enhancement
   ```

3. **Make Changes Following Standards**:
   - Follow module structure guidelines
   - Add comprehensive tests
   - Update documentation
   - Follow naming conventions

4. **Pre-Commit Validation**:
   ```bash
   # Install pre-commit hooks
   pip install pre-commit
   pre-commit install
   
   # Run pre-commit checks
   pre-commit run --all-files
   ```

5. **Test Your Changes**:
   ```bash
   # Run Terraform tests
   cd modules/your-module
   terraform test
   
   # Validate examples work
   cd examples/basic
   terraform init
   terraform plan
   ```

6. **Submit Pull Request**:
   - Clear description of changes
   - Link to related issues
   - Include test results
   - Update documentation

### Pre-Commit Configuration

The project uses pre-commit hooks to ensure code quality:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_docs
      - id: terraform_validate
      - id: terraform_tflint
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-merge-conflict
```

**Required Checks**:
- **Terraform formatting** (`terraform fmt`)
- **Documentation generation** (`terraform-docs`)
- **Terraform validation** (`terraform validate`)
- **Linting** (`tflint`)
- **YAML syntax** validation
- **Trailing whitespace** removal

### Quality Gates

**PRs will NOT be merged if**:
- ❌ **Tests are failing**
- ❌ **Pre-commit checks fail**
- ❌ **Documentation is incomplete**
- ❌ **Examples don't work**
- ❌ **Security issues identified**
- ❌ **Breaking changes without migration guide**

**PRs will be prioritized if**:
- ✅ **Comprehensive tests included**
- ✅ **Documentation follows standards**
- ✅ **Examples demonstrate usage**
- ✅ **Follows established patterns**
- ✅ **Includes troubleshooting guidance**

## Review Process

### Documentation Review Checklist
- [ ] All sections present and complete
- [ ] Examples tested and working
- [ ] Technical accuracy verified
- [ ] Consistent with other modules
- [ ] FAQ addresses common questions
- [ ] Troubleshooting covers known issues
- [ ] Links functional and current
- [ ] **Tests pass and provide good coverage**
- [ ] **Pre-commit hooks pass**

### Code Review Requirements
- Technical implementation review
- Security assessment
- Performance considerations
- Multi-region compatibility
- Cleanup mechanism validation
- **Test coverage and quality**
- **Documentation completeness**

## Module Standards Compliance

This module (Unreal Cloud DDC) serves as the **gold standard** for:
- **Multi-region deployment patterns**
- **Comprehensive documentation**
- **Robust troubleshooting guides**
- **User-friendly configuration**
- **Reliable cleanup mechanisms**

Other modules should follow these patterns and standards to ensure consistency across the Cloud Game Development Toolkit.