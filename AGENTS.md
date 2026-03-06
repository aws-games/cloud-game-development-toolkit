# Cloud Game Development Toolkit - AI Agent Guide

## Project Overview

The **Cloud Game Development Toolkit (CGD Toolkit)** is a collection of Terraform modules, scripts, and configurations for deploying game development infrastructure and tools on AWS. The project enables game studios to deploy production-ready infrastructure for Perforce, Jenkins, Unreal Engine Horde, VDI workstations, and other game development tools.

### Project Structure

```text
cloud-game-development-toolkit/
├── assets/              # Reusable scripts, Packer templates, Ansible playbooks
├── modules/             # Terraform modules for game dev infrastructure
│   ├── jenkins/        # Jenkins CI/CD infrastructure
│   ├── perforce/       # Perforce version control
│   ├── teamcity/       # TeamCity CI/CD infrastructure
│   ├── unity/          # Unity-specific tools
│   ├── unreal/         # Unreal Engine tools (Horde, Cloud DDC)
│   └── vdi/            # Virtual desktop infrastructure
├── samples/            # Complete Terraform configurations
└── docs/               # Documentation source
```

### Key Technologies

- **Terraform**: Infrastructure as Code (IaC) for AWS resource provisioning
- **AWS**: Cloud infrastructure provider
- **Packer**: Machine image building
- **Ansible**: Configuration management
- **Docker**: Container images for services

## Design Philosophy

### 1. Modularity and Flexibility

Modules are designed as building blocks, not complete solutions. Users compose modules to fit their specific needs rather than being forced into opinionated architectures.

**Key Principles:**

- Modules provide infrastructure components, not complete solutions
- Configuration decisions happen in examples, not module internals
- Support multiple deployment patterns through simple variables
- Enable customization without requiring module forking

### 2. Conservative Variable Exposure

Every exposed variable is a commitment to backward compatibility. We start with minimal variables based on known use cases and add more when users request them.

**Guidelines:**

- Start with minimal variables
- Add variables based on user demand (demand-driven)
- Default values should work for 80% of use cases
- Easier to add than remove (breaking changes are painful)

### 3. Security by Default

Game development infrastructure often handles sensitive assets and player data. Security mistakes are costly and hard to fix later.

**Security Patterns:**

- No `0.0.0.0/0` ingress rules in module code (users explicitly define allowed access)
- Private-first architecture with controlled external access
- HTTPS enforcement for internet-facing services
- User-controlled security groups with their own rules

### 4. Readability First

Game development teams often include infrastructure newcomers. Clear, understandable code reduces onboarding time and prevents misconfigurations.

**Code Standards:**

- Prefer explicit over implicit configurations
- Use descriptive variable names that explain purpose
- Self-documenting code over clever abstractions
- Comment complex logic with business context

## Module Design Standards

### Naming Conventions

Use descriptive, purpose-driven resource names:

```hcl
# ✅ GOOD - Descriptive names
resource "aws_lb" "nlb" { }                    # Network Load Balancer
resource "aws_lb" "alb" { }                    # Application Load Balancer
resource "aws_security_group" "internal" { }   # Internal communication

# ❌ BAD - Generic names
resource "aws_lb" "this" { }
resource "aws_lb" "this2" { }
```

### Variable Structure

Use a hybrid approach:

- **Flat variables** for simple, common settings
- **Complex objects** for logical grouping when they provide clear value
- **Submodule alignment** - Complex objects that map directly to submodules

```hcl
# Flat for simple settings
variable "vpc_id" {
  type        = string
  description = "VPC ID for deployment"
}

# Complex objects for logical grouping
variable "load_balancer_config" {
  type = object({
    nlb = object({
      enabled         = optional(bool, true)
      internet_facing = optional(bool, true)
      subnets        = list(string)
    })
  })
}
```

### Resource Patterns

**Prefer direct resources over remote modules:**

```hcl
# ✅ PREFERRED - Direct resource creation
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  # Direct configuration gives full control
}

# ❌ AVOID - Remote module dependency
module "eks" {
  source = "registry.terraform.io/example/eks/aws"
  # Adds complexity, version dependencies, limited customization
}
```

**When remote modules are needed, fork them first** for full control over changes and updates.

## Testing Strategy

### Unit Tests with Mocked Providers

All modules use Terraform's native test framework with **mocked providers** to validate module logic without creating actual AWS resources.

**Benefits:**

- Zero AWS costs (no resources created)
- No cleanup required
- No AWS credentials needed
- Fast execution (seconds)
- CI-ready without authentication

**Test Structure:**

```hcl
# Mock AWS provider
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
}

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

**What Gets Tested:**

- ✅ Variable validation logic
- ✅ Conditional resource creation
- ✅ Resource count calculations
- ✅ Dynamic block logic
- ❌ Actual AWS resource creation
- ❌ AWS API behavior

**Running Tests:**

```bash
cd modules/{module-name}
terraform init
terraform test
```

See `TERRAFORM_TESTING_STRATEGY.md` for comprehensive testing guidelines.

## Documentation Standards

### Module Documentation

Each module must include:

1. **README.md** - Module overview, usage examples, input/output documentation
2. **examples/** - Working example configurations
3. **tests/** - Terraform test files with mocked providers

### Test Documentation

Test directories should include:

- **README.md** - Test scenarios, what gets tested, how to run
- **QUICKSTART.md** - 2-minute quick start guide (optional for complex modules)

### Avoid Documentation Proliferation

- Don't create multiple README files for the same purpose
- Consolidate related documentation
- Use existing documentation locations (CONTRIBUTING.md, DESIGN_STANDARDS.md, etc.)
- Reference external documentation rather than duplicating it

## Development Workflow

### Making Changes

1. **Fork and Branch**: Create a feature branch from `main`
2. **Follow Standards**: Adhere to design standards in `modules/DESIGN_STANDARDS.md`
3. **Write Tests**: Add unit tests with mocked providers
4. **Test Locally**: Run `terraform test` to validate changes
5. **Document**: Update README and examples as needed
6. **Commit**: Use conventional commit messages
7. **Pull Request**: Submit PR with clear description

### Conventional Commits

PR titles must follow conventional commit format:

```text
feat(module): add new feature
fix(module): resolve issue
docs(module): update documentation
test(module): add tests
```

### Pre-commit Checks

The project uses pre-commit hooks for:

- Terraform formatting (`terraform fmt`)
- Terraform validation
- Security scanning (Checkov)
- Documentation generation

## Common Patterns

### Networking

**3-Tier Architecture:**

- `application_subnets` - Primary business applications
- `service_subnets` - Supporting services (databases, caches)
- `load_balancer_config` - Load balancer configuration

**Load Balancer Strategy:**

- Default to NLB for most services
- ALB when needed for HTTP/HTTPS routing
- User controls creation via boolean flags

**DNS Patterns:**

- Regional endpoints by default (`us-east-1.service.company.com`)
- Private zones for internal service discovery
- Global endpoints optional for advanced routing

### Security Groups

```hcl
variable "security_groups" {
  type        = list(string)
  description = "Security group IDs for external access"
  default     = []
}

# Module creates internal security groups
resource "aws_security_group" "internal" {
  name_prefix = "${local.name_prefix}-internal-"
  vpc_id      = var.vpc_id
}
```

### IAM Roles and Policies

```hcl
variable "create_default_role" {
  type        = bool
  description = "Create default IAM role"
  default     = true
}

variable "custom_role_arn" {
  type        = string
  description = "Custom IAM role ARN (if not using default)"
  default     = null
}
```

## AI Agent Guidelines

### When Helping with Module Development

1. **Read Design Standards First**: Always reference `modules/DESIGN_STANDARDS.md`
2. **Follow Naming Conventions**: Use descriptive resource names, not generic ones
3. **Test with Mocked Providers**: Create unit tests, not integration tests
4. **Avoid Remote Modules**: Prefer direct resources unless there's a compelling reason
5. **Security First**: Never add `0.0.0.0/0` ingress rules without explicit user request

### When Writing Tests

1. **Use Mocked Providers**: Always use `mock_provider` blocks
2. **Test Logic, Not AWS**: Focus on conditionals, counts, validation
3. **Provide Test Values**: Include test values directly in test files
4. **Add Assertions**: Test expected behavior with clear error messages
5. **No Integration Tests**: Don't create tests that require actual AWS resources

### When Creating Documentation

1. **Consolidate**: Don't create multiple README files for the same purpose
2. **Reference Existing**: Link to existing documentation rather than duplicating
3. **Be Concise**: Focus on essential information
4. **Use Examples**: Show, don't just tell
5. **Update Existing**: Enhance existing docs rather than creating new ones

### When Reviewing Code

1. **Check Standards**: Verify adherence to design standards
2. **Validate Tests**: Ensure tests use mocked providers
3. **Review Security**: Check for security anti-patterns
4. **Assess Complexity**: Ensure code is readable and maintainable
5. **Verify Documentation**: Confirm README and examples are updated

## Resources

- **Documentation**: <https://aws-games.github.io/cloud-game-development-toolkit/>
- **Design Standards**: `modules/DESIGN_STANDARDS.md`
- **Contributing**: `CONTRIBUTING.md`
- **Discussions**: <https://github.com/aws-games/cloud-game-development-toolkit/discussions/>
- **Roadmap**: <https://github.com/orgs/aws-games/projects/1/views/1>

## Agent-Specific Context

Different AI agents may have additional context files:

- **Kiro**:
  - `.kiro/steering/*.md` - Automatically loaded steering files (project context)
  - `.kiro/rules/*.md` - Kiro-specific rules and workflows

## Getting Help

- **Questions**: Use GitHub Discussions
- **Bugs**: File GitHub Issues
- **Security**: Follow AWS vulnerability reporting process
- **Contributing**: See CONTRIBUTING.md

---

**Note for AI Agents**: This project prioritizes readability, security, and modularity. When in doubt, favor explicit over implicit, simple over clever, and secure by default. Always test with mocked providers and follow the established design patterns.
