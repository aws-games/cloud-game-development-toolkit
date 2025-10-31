# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The **Cloud Game Development Toolkit (CGD Toolkit)** is a collection of Terraform modules, Packer templates, and sample configurations for deploying game development infrastructure on AWS. The toolkit is designed for piecemeal usage—studios can use individual modules or complete samples based on their needs.

## Repository Structure

The repository consists of three main components:

### 1. Assets (`/assets`)
- **Packer templates** for creating AMIs (Perforce servers, build agents, virtual workstations)
- **Jenkins pipelines** for CI/CD workflows
- **Ansible playbooks** for post-deployment configuration

### 2. Modules (`/modules`)
Terraform modules organized by game development tool or service:
- **Perforce** - Version control (P4 Server, P4 Auth, P4 Code Review)
- **Jenkins** - CI/CD orchestration
- **TeamCity** - Alternative CI/CD platform
- **Unity** - Unity Accelerator and Floating License Server
- **Unreal** - Horde build system and Cloud DDC
- **VDI** - Virtual desktop infrastructure

Each module follows a consistent structure:
```
modules/<service-name>/
├── main.tf           # Parent module orchestration
├── variables.tf      # Input variables with validation
├── outputs.tf        # Module outputs
├── versions.tf       # Provider version constraints
├── modules/          # Submodules (when needed)
├── examples/         # Working example configurations
└── tests/            # Terraform tests
```

### 3. Samples (`/samples`)
Complete, deployable Terraform configurations demonstrating module usage:
- **simple-build-pipeline** - Perforce + Jenkins integration
- **unreal-cloud-ddc-single-region** - Unreal Cloud DDC deployment
- **unity-build-pipeline** - Unity build infrastructure

Samples follow a three-phase deployment pattern:
1. **Predeployment**: Provision prerequisites (AMIs, certificates, Route53 zones)
2. **Deployment**: Run `terraform apply` with configured variables
3. **Postdeployment**: Execute configuration steps (Ansible, manual setup)

## Module Design Standards

All modules follow the design standards documented in `modules/DESIGN_STANDARDS.md`. Key principles:

### Variable Structure
- **Flat variables** for simple, common settings
- **Complex objects** for logical grouping (e.g., `load_balancer_config`, `centralized_logging`)
- **Submodule alignment** - Parent variables map directly to submodules (e.g., `infra_config`, `services_config`)
- **Intelligent defaults** - Work for 80% of use cases

### Security Patterns
- **No 0.0.0.0/0 ingress rules** in module code - users explicitly define allowed access
- **Private-first architecture** with controlled external access
- **HTTPS enforcement** for internet-facing services
- **User-controlled security groups** for external access, module-created groups for internal communication

### Networking Standards
- **3-tier architecture**: application_subnets, service_subnets, load_balancer_subnets
- **NLB by default** for most services (ALB when needed for HTTP routing/WAF)
- **Regional DNS endpoints** following AWS patterns (e.g., `us-east-1.service.company.com`)
- **Private DNS zones** always created for internal service discovery

### Multi-Region Support
- **Performance-driven** - Multi-region is for global team performance, not DR
- **Single apply requirement** - All regions deployed with one `terraform apply` for inherently multi-region apps
- **AWS Provider v6** - Enhanced region support eliminates AWS provider aliases
- **Maximum 2 regions** per state file - use separate deployments for more regions
- **Primary/secondary pattern** - Primary creates shared resources, secondary references them

### Infrastructure Boundaries
**Modules DO NOT create:**
- VPCs and subnets
- SSL/TLS certificates
- Public Route53 hosted zones
- VPC-to-VPC connectivity
- Internet/NAT gateways

**Modules DO create:**
- Private DNS zones
- Security groups for service-specific access
- Load balancers (NLB/ALB)
- DNS records in provided zones

## Common Commands

### Documentation
```bash
# Build documentation locally
make docs-run VERSION=v1.0.0 ALIAS=latest

# Deploy documentation to GitHub Pages
make docs-deploy-github VERSION=v1.0.0 ALIAS=latest
```

### Module Development
```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Run tests
terraform test
```

### Creating AMIs with Packer
```bash
# Perforce server (x86)
packer init ./assets/packer/perforce/p4-server/perforce_x86.pkr.hcl
packer build ./assets/packer/perforce/p4-server/perforce_x86.pkr.hcl

# Linux build agent (Amazon Linux 2023)
cd assets/packer/build-agents/linux
packer build -var "public_key=<ssh-public-key>" amazon-linux-2023-x86_64.pkr.hcl

# Windows build agent
cd assets/packer/build-agents/windows
packer build -var "public_key=<ssh-public-key>" windows.pkr.hcl
```

## Architecture Patterns

### Provider Configuration
- **Root modules** define provider versions and configurations
- **Parent modules** create resources directly and orchestrate submodules
- **Submodules** separate infrastructure (AWS) from services (Kubernetes/Helm)
- **AWS Provider v6** automatically inherits region from module configuration

### Resource Naming
- **Descriptive logical names** (e.g., `nlb`, `alb`, `main`, `internal`) - avoid generic names like `this`
- **Random IDs for uniqueness**: `random_id` with project_prefix and name as keepers
- **Predictable patterns**: `${project_prefix}-${name}-${resource_type}-${random_suffix}`

### Centralized Logging
All modules support optional CloudWatch-based logging with three tiers:
- **Infrastructure logs** - AWS services (NLB, ALB, EKS, RDS)
- **Application logs** - Primary service logs
- **Service logs** - Supporting services (databases, auth services)

Configurable retention periods and CloudWatch integration for monitoring solutions.

### Remote Module Philosophy
- **Prefer direct resources** over remote module dependencies
- **Use remote modules only when** there's clear benefit and stable maintenance
- **Fork-first strategy** - Fork remote modules locally for full control
- **Minimize external dependencies** - Reduces version conflicts and complexity

## Development Workflow

### For New Modules
1. Follow the standard directory structure
2. Implement 3-tier networking variables
3. Use descriptive resource names
4. Create private DNS zones automatically
5. Implement security group strategy (no 0.0.0.0/0 ingress)
6. Add comprehensive examples with `versions.tf`
7. Document architecture and usage patterns

### For Existing Modules
1. Plan breaking changes for major versions only
2. Add `moved` blocks for renamed resources
3. Test upgrade paths with real state files
4. Create migration documentation

## Testing and Validation

- Module tests located in `modules/<service>/tests/`
- Each test includes a `setup/` directory for CI parameter retrieval
- Examples serve as integration tests and must be fully functional
- Use conventional commits for PR titles (enforced by automation)

## Contributing

- Follow conventional commits specification
- Open issues for significant work before submitting PRs
- Ensure local tests pass before submitting
- Variable changes require backward compatibility or major version bump
- Documentation is auto-generated from README.md files

## Important Notes

- **AWS Provider v6 required** - Enhanced region support for simplified multi-region
- **Provider versions** - Root modules must satisfy all module provider constraints
- **Security first** - Users control external access, modules handle internal communication
- **Breaking changes** - Require major version bumps and `moved` blocks for renamed resources
- **Multi-region** - Only for inherently multi-region apps (Perforce, DDC); use separate deployments for most applications
