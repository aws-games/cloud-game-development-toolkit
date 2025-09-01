# CGD Toolkit Design Standards

## Module Design Principles

Follow the Cloud Game Development Toolkit design principles for all Terraform modules:

### Core Tenets
- **Serverless First**: Prefer managed services and serverless technologies
- **Container First**: Use ECS/EKS for scalable, maintainable services  
- **Security by Default**: Implement least privilege access and private-first networking
- **Deep Customization**: Provide extensive configuration options with sensible defaults
- **Integration Ready**: Design modules to work together seamlessly

### Compute Strategy (Preference Order)
1. **Serverless** (Lambda, Fargate) - Preferred for simplicity and cost
2. **Managed Containers** (ECS Fargate, EKS Fargate) - For scalable services
3. **Container Orchestration** (ECS EC2, EKS EC2) - When Fargate limitations apply
4. **Dedicated EC2** - Only when technology requirements mandate it

### Networking Architecture
- **Private-First Design**: Services always deployed in private subnets
- **NLB-First Strategy**: All traffic routed through load balancers
- **Access Method Control**: All modules must support `access_method` variable (external/internal)

### Access Method Pattern
**REQUIRED**: All modules must implement this pattern:
```hcl
variable "access_method" {
  type = string
  description = "external/public: Internet → Public NLB | internal/private: VPC → Private NLB"
  default = "external"
  
  validation {
    condition = contains(["external", "internal", "public", "private"], var.access_method)
    error_message = "Must be 'external'/'public' or 'internal'/'private'"
  }
}
```

## AWS Provider Resource Standards

### Security Groups
**REQUIRED**: Use dedicated security group rule resources, never inline rules:
```hcl
# ✅ CORRECT - Use dedicated rule resources
resource "aws_vpc_security_group_ingress_rule" "example" {
  security_group_id = aws_security_group.example.id
  description       = "HTTP access from office network"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "203.0.113.0/24"
  
  tags = {
    Name = "http-office-access"
  }
}

resource "aws_vpc_security_group_egress_rule" "example" {
  security_group_id = aws_security_group.example.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  
  tags = {
    Name = "all-egress"
  }
}

# ❌ INCORRECT - Never use inline rules or aws_security_group_rule
resource "aws_security_group" "bad_example" {
  ingress {  # Don't use inline rules
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "deprecated" {  # Don't use this resource
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

### IAM Policies
**REQUIRED**: Use `aws_iam_policy_document` data source instead of `jsonencode()`:
```hcl
# ✅ CORRECT - Use data source
data "aws_iam_policy_document" "example" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.example.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "example" {
  name   = "example-policy"
  policy = data.aws_iam_policy_document.example.json
}

# ❌ INCORRECT - Avoid jsonencode unless absolutely necessary
resource "aws_iam_policy" "bad_example" {
  name = "bad-example"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "*"
      }
    ]
  })
}
```

### IAM Roles
**REQUIRED**: Use attachment resources instead of deprecated arguments:
```hcl
# ✅ CORRECT - Use attachment resources
resource "aws_iam_role" "example" {
  name = "example-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  
  # Don't use managed_policy_arns or inline_policy (deprecated)
}

# Managed policy attachments
resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Inline policy attachments  
resource "aws_iam_role_policy" "example" {
  name = "example-inline-policy"
  role = aws_iam_role.example.id
  policy = data.aws_iam_policy_document.inline_policy.json
}

# ❌ INCORRECT - Don't use deprecated arguments
resource "aws_iam_role" "bad_example" {
  name = "bad-example"
  
  managed_policy_arns = [  # Deprecated
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]
  
  inline_policy {  # Deprecated
    name = "inline-policy"
    policy = jsonencode({...})
  }
}
```

### Security Validation
**REQUIRED**: Prevent 0.0.0.0/0 ingress access:
```hcl
variable "allowed_external_cidrs" {
  type = list(string)
  description = "CIDR blocks for external access. Use prefix lists for multiple IPs."
  
  validation {
    condition = !contains(var.allowed_external_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed for ingress. Specify actual CIDR blocks or use prefix lists."
  }
}
```

## Module Structure Standards

### Parent Module with Submodules Pattern
```
modules/
├── service-name/
│   ├── main.tf              # Parent module orchestration
│   ├── variables.tf         # Configuration objects
│   ├── outputs.tf           # Standardized outputs
│   ├── versions.tf          # Terraform and provider version constraints
│   ├── README.md            # Parent module documentation
│   ├── modules/
│   │   ├── component-a/     # Submodule for distinct component
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── versions.tf
│   │   │   └── README.md
│   │   └── component-b/     # Submodule for separate concerns
│   ├── tests/               # Terraform tests with type prefix and numbered execution order
│   │   ├── setup/           # Shared test setup
│   │   │   ├── ssm.tf
│   │   │   └── versions.tf
│   │   ├── unit_01_basic_single_region.tftest.hcl
│   │   ├── unit_02_basic_multi_region.tftest.hcl
│   │   ├── integration_01_single_region.tftest.hcl
│   │   └── integration_02_multi_region.tftest.hcl
│   └── examples/            # Working examples by function
│       ├── single-region-basic/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   ├── versions.tf   # REQUIRED - All provider versions
│       │   ├── providers.tf  # OPTIONAL - Provider configurations
│       │   └── README.md
│       └── multi-region-basic/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           ├── versions.tf   # REQUIRED - All provider versions
│           ├── providers.tf  # OPTIONAL - Provider configurations
│           └── README.md
```

### Required Files for All Modules
- `main.tf` - Resource definitions and submodule calls
- `variables.tf` - Input variables with validation
- `outputs.tf` - Standardized outputs
- `versions.tf` - Terraform and provider version constraints

- `README.md` - Comprehensive documentation following standard template
- `tests/` - Terraform tests (unit and integration)
- `examples/` - Working examples in subdirectories by function

### Required Files for All Examples
- `main.tf` - Example configuration using the module
- `variables.tf` - Input variables for the example
- `outputs.tf` - Example outputs
- `versions.tf` - **REQUIRED** - Terraform and provider version constraints
- `providers.tf` - **OPTIONAL** - Provider-specific configurations (when needed)
- `README.md` - Example documentation

### File Purposes

**`versions.tf`** - Define minimum versions and provider requirements:
```hcl
terraform {
  required_version = ">= 1.11"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"  # Required for enhanced region support
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.33.0"
    }
  }
}
```

**Reference**: See `modules/unreal/unreal-cloud-ddc-fixes/versions.tf` for current version requirements (subject to change).

**`versions.tf`** - **REQUIRED** for all examples (standalone Terraform configurations):
```hcl
# examples/single-region-basic/versions.tf
terraform {
  required_version = ">= 1.11"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
  }
}
```

**`providers.tf`** - Optional for examples when provider-specific configuration needed:
```hcl
# examples/single-region-basic/providers.tf
# Only include when providers need specific configuration
provider "kubernetes" {
  host                   = module.service.cluster_endpoint
  cluster_ca_certificate = base64decode(module.service.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.service.cluster_name]
  }
}
```

## Multi-Region Support Standards

### AWS Provider v6 Enhanced Region Support
**REQUIRED**: Always use AWS Provider v6 enhanced region support for multi-region deployments:

```hcl
# ✅ CORRECT - Enhanced region support (AWS Provider v6+)
module "service_primary" {
  source = "./modules/service"
  
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
    # AWS provider automatically inherited based on region
  }
  
  region = "us-east-1"
}

module "service_secondary" {
  source = "./modules/service"
  
  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
    # AWS provider automatically inherited based on region
  }
  
  region = "us-west-2"
}

# ❌ INCORRECT - Don't explicitly pass AWS provider
module "service_bad" {
  providers = {
    aws        = aws.secondary  # Not needed with v6
    kubernetes = kubernetes.secondary
  }
}
```

**Benefits**: AWS Provider v6 automatically handles region inheritance, reducing provider configuration complexity.

## README Template Standards

### Consistent README Structure
**REQUIRED**: All READMEs (parent modules, submodules, examples) must follow this structure:

```markdown
# [Module/Example Name]

## Overview
[Brief description of what this module/example does]

## Architecture
[Architecture diagram and explanation]

## Usage
[Basic usage example with code block]

## Requirements
[Prerequisites, versions, dependencies]

## Providers
[Provider requirements and versions]

## Modules
[Submodules used, if applicable]

## Resources
[Key AWS resources created]

## Inputs
[Variable documentation - auto-generated preferred]

## Outputs
[Output documentation - auto-generated preferred]

## Examples
[Links to example configurations]

## Contributing
[Link to contributing guidelines]

## License
[License information]
```

### README Generation
**RECOMMENDED**: Use terraform-docs for automatic documentation generation:
```bash
terraform-docs markdown table --output-file README.md .
```
## Provider Version Management Standards

### Example-Level Version Requirements
**REQUIRED**: All examples must have a `versions.tf` file with complete provider version constraints.

**Rationale**: Examples are standalone Terraform configurations that users run directly with `terraform init`. They must specify all required provider versions to ensure compatibility and prevent conflicts.

**Template for Example versions.tf**:
```hcl
terraform {
  required_version = ">= 1.11"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
    # Include ALL providers used by the example and its modules
  }
}
```

### Version Compatibility Rules
**CRITICAL**: Example provider versions must be compatible with all modules and submodules used.

**Compatibility Check Process**:
1. **Identify all providers** used by the example's module tree
2. **Check version constraints** in parent module and submodules  
3. **Ensure example versions satisfy all constraints** (use `>= minimum_required`)
4. **Test with `terraform init`** to verify no conflicts

**Example Compatibility Matrix**:
```
Example:     helm >= 3.0.0
Parent:      helm >= 3.0.0  ✅ Compatible
Submodule:   helm >= 2.9.0  ✅ Compatible (3.0.0 satisfies >= 2.9.0)
Remote Dep:  helm >= 3.0.0  ✅ Compatible
Result:      Uses helm 3.x   ✅ Success
```

### Version Conflict Resolution
**When conflicts occur**:
1. **Update remote dependencies** (if you control them)
2. **Align local module versions** to be compatible
3. **Use minimum viable versions** that satisfy all constraints
4. **Document version decisions** in module README

**Never**:
- Use conflicting version ranges (`>= 3.0.0` vs `< 3.0.0`)
- Ignore version constraints from dependencies
- Skip version declarations in examples

## Centralized Logging Standards

### Module-Level Logging Pattern
**REQUIRED**: All modules must implement centralized logging following the standardized pattern from [Issue #726](https://github.com/aws-games/cloud-game-development-toolkit/issues/726).

#### Standard Log Structure
```
${local.name_prefix}-logs-${random_suffix}/
├── infrastructure/       # AWS managed service logs
│   ├── nlb/             # Network Load Balancer access logs
│   ├── alb/             # Application Load Balancer access logs
│   ├── eks/             # EKS control plane logs
│   ├── rds/             # RDS database logs (if applicable)
│   └── vpc/             # VPC Flow logs (future)
├── application/         # Primary business application logs
│   ├── ddc/            # DDC service logs (DDC module)
│   ├── horde/          # Horde service logs (Horde module)
│   └── jenkins/        # Jenkins controller logs (Jenkins module)
├── service/            # Supporting service logs
│   ├── scylla/         # ScyllaDB database logs
│   ├── auth/           # Authentication services (Perforce p4-auth)
│   └── review/         # Code review services (Perforce p4-code-review)
# platform/ - Future category for cross-cutting services (monitoring, etc.)
```

#### CloudWatch Log Groups
```
${local.name_prefix}/infrastructure/{service}  # AWS infrastructure logs
${local.name_prefix}/application/{service}     # Business application logs
${local.name_prefix}/service/{service}         # Supporting service logs
# ${local.name_prefix}/platform/{service}  # Future: Platform service logs
```

#### Implementation Requirements
- **Single S3 bucket per module** with organized prefixes for cost efficiency
- **CloudWatch Log Groups** for real-time monitoring and dashboard consumption
- **Descriptive tags** on log groups explaining their purpose and content
- **Proper IAM permissions** for all log sources (CloudWatch Agent, ELB service account, etc.)
- **Configurable retention** with sensible defaults (30 days)
- **Future-ready structure** - create empty log groups for planned services (zero cost)

#### Standard Variables
```hcl
variable "enable_centralized_logging" {
  type = bool
  description = "Enable centralized logging for all module services"
  default = true
}

variable "log_retention_days" {
  type = number
  description = "CloudWatch log retention in days"
  default = 30
}

variable "centralized_logs_bucket" {
  type = string
  description = "Existing S3 bucket for centralized logs (if null, creates new bucket)"
  default = null
}
```

#### Rationale
- **infrastructure/** - AWS managed services (NLB, ALB, EKS, RDS) for clear separation
- **application/** - Primary business logic services for easy dashboard filtering
- **service/** - Supporting services following Perforce auth/review pattern
# - **platform/** - Future: Cross-cutting services like monitoring, logging aggregation

**Note**: This structure may have minor deviations per module based on specific service architecture, but should be followed as closely as possible for consistency. The structure is subject to change in future versions as the CGD Toolkit evolves.

#### Dashboard Integration
This structure is optimized for Amazon Managed Grafana consumption:
- **CloudWatch Logs** as primary data source for real-time queries
- **S3** for long-term archival and cost optimization
- **Organized prefixes** enable easy filtering and correlation across services

#### Application Metrics Gap
**MISSING**: DDC application metrics (cache hit rates, response times) are not currently configured in CGD Toolkit modules. These metrics require:
- **DDC application configuration** to expose Prometheus endpoints
- **ServiceMonitor resources** to scrape application metrics
- **Custom dashboards** for DDC-specific performance monitoring

**Current Coverage**:
- ✅ **EKS pod metrics** - Resource usage, health checks (via CloudWatch Container Insights)
- ✅ **NLB metrics** - Traffic, target health, connection counts (automatic CloudWatch metrics)
- ❌ **DDC application metrics** - Cache performance, response times (requires application-level configuration)
