# 📋 Module Contribution Guide

This guide defines the gold standards for building excellent CGD Toolkit modules. Follow these patterns to create consistent, maintainable, and secure infrastructure modules.

## ⭐ Gold Standards Overview

Quick reference for what makes an excellent CGD Toolkit module:

- **🏗️ Structure**: Simple parent modules with optional submodules only when justified
- **🏷️ Variables**: `existing_` prefix for external resources, purpose-based naming
- **🏠 Resources**: Random IDs for predictable names, standardized logical names
- **🔒 Security**: No 0.0.0.0/0 ingress rules, HTTPS-first policy, user-controlled access
- **🌐 DNS**: Always create private zones, regional endpoint patterns
- **🧪 Testing**: Terraform Test Framework with setup/ directory for CI parameters
- **📚 Examples**: Architecture decisions in examples, not module variables

## 🏗️ Module Structure Standards

### **Preferred Structure**

```
module-name/
├── README.md            # Parent module documentation
├── data.tf              # Data source definitions
├── locals.tf            # Local value calculations
├── main.tf              # Parent module orchestration
├── outputs.tf           # Standardized outputs
├── variables.tf         # Input variables with validation
├── versions.tf          # Terraform and provider version constraints
├── examples/
│   └── complete/        # Shows parent module usage
│       ├── README.md    # Example documentation
│       ├── main.tf      # Example configuration using the module
│       ├── outputs.tf   # Example outputs
│       ├── variables.tf # Example input variables
│       └── versions.tf  # Example version constraints
├── modules/ (OPTIONAL - only when dependency conflicts between providers)
│   ├── infra/           # AWS provider submodule (creates EKS cluster)
│   │   ├── README.md    # Submodule documentation
│   │   ├── main.tf      # AWS resource definitions
│   │   ├── outputs.tf   # Submodule outputs
│   │   ├── variables.tf # Submodule input variables
│   │   └── versions.tf  # Submodule version constraints
│   └── services/        # Kubernetes/Helm provider submodule (requires EKS cluster)
│       ├── README.md    # Submodule documentation
│       ├── main.tf      # Kubernetes/Helm resource definitions
│       ├── outputs.tf   # Submodule outputs
│       ├── variables.tf # Submodule input variables
│       └── versions.tf  # Submodule version constraints
└── tests/
    ├── setup/           # Shared test setup (REQUIRED)
    │   ├── ssm.tf       # SSM parameter retrieval
    │   └── versions.tf  # Test setup versions
    ├── unit_01_basic_single_region.tftest.hcl          # Unit test (plan only)
    ├── unit_02_basic_multi_region.tftest.hcl           # Unit test (plan only)
    ├── integration_01_single_region_deploy.tftest.hcl  # Integration/E2E test (apply)
    └── integration_02_multi_region_deploy.tftest.hcl   # Integration/E2E test (apply)
```

### **When to Use Submodules**

**✅ Use Submodules When:**
- **Different providers required** (AWS vs Kubernetes vs Helm)
- **Dependency conflicts between providers** (EKS cluster must exist before Kubernetes resources)
- **Clear logical separation** benefits maintenance
- **Reusable across multiple parent modules**

**❌ Avoid Submodules When:**
- Same provider throughout
- Tightly coupled resources
- No clear separation benefit
- Adds complexity without value

**Example Excellence Pattern:**
```hcl
# DDC Module - Different providers justify submodules
module "ddc_infra" {
  source = "./modules/ddc-infra"
  providers = { aws = aws }
}

module "ddc_services" {
  source = "./modules/ddc-services"
  providers = {
    kubernetes = kubernetes
    helm = helm
  }
  depends_on = [module.ddc_infra]
}
```

**Default Excellence**: Most modules should be implemented as single parent modules without submodules.

## 🏷️ Variable Naming Standards

### **Excellence Pattern: `existing_` Prefix for External Resources**

```hcl
# ✅ EXCELLENT - Use existing_ prefix for user-provided resources
variable "existing_vpc_id" {
  type        = string
  description = "VPC ID where resources will be created"
}

variable "existing_load_balancer_subnets" {
  type        = list(string)
  description = "Subnets for load balancers (public for internet, private for VPC-only)"
}

variable "existing_service_subnets" {
  type        = list(string)
  description = "Subnets for services (EKS, databases, applications)"
}

variable "existing_security_groups" {
  type        = list(string)
  description = "Security group IDs for external access"
  default     = []
}

# ❌ AVOID - Topology-based naming
variable "public_subnets" { }  # Implies specific network topology
variable "private_subnets" { } # Less flexible than purpose-based naming
```

### **Excellence Pattern: Purpose-Based Variable Names**

```hcl
# ✅ EXCELLENT - Purpose-based, configurable
variable "project_prefix" {
  type        = string
  description = "Prefix for all resource names"
  default     = "cgd"
}

variable "debug_mode" {
  type        = string
  description = "Debug mode: 'enabled' relaxes security constraints for troubleshooting, 'disabled' enforces production security"
  default     = "disabled"

  validation {
    condition     = contains(["enabled", "disabled"], var.debug_mode)
    error_message = "debug_mode must be 'enabled' or 'disabled'"
  }
}

# ❌ AVOID - Opinionated variables
variable "access_method" { }  # Let examples show patterns instead
```

### **Excellence Pattern: Tiered Security Group Strategy**

```hcl
# General access (applies to all public-facing components)
variable "existing_security_groups" {
  type        = list(string)
  description = "Security group IDs for general access to public services"
  default     = []
}

# Component-specific access (when needed)
variable "existing_load_balancer_security_groups" {
  type        = list(string)
  description = "Additional security group IDs for load balancer access"
  default     = []
}

variable "existing_eks_security_groups" {
  type        = list(string)
  description = "Additional security group IDs for EKS API access"
  default     = []
}
```

## 🏠 Resource Naming Standards

### **Excellence Pattern: Random IDs for Predictable Names**

```hcl
# ✅ EXCELLENT - Predictable, conflict-free naming
resource "random_id" "suffix" {
  byte_length = 4
  keepers = {
    project_prefix = var.project_prefix
    name          = local.name
  }
}

locals {
  name_prefix = "${var.project_prefix}-${local.name}"
  name_suffix = random_id.suffix.hex

  # Predictable, readable names
  nlb_name = "${local.name_prefix}-nlb-${local.name_suffix}"
  # Result: "cgd-unreal-cloud-ddc-nlb-a1b2c3d4"
}

# ❌ AVOID - Unpredictable name_prefix
resource "aws_lb" "nlb" {
  name_prefix = "cgd-ddc-"  # AWS generates random suffix
}
```

### **Excellence Pattern: Standardized Logical Names**

```hcl
# ✅ EXCELLENT - Use these EXACT logical names in every module
resource "aws_lb" "nlb" { }                    # Network Load Balancer
resource "aws_lb" "alb" { }                    # Application Load Balancer
resource "aws_eks_cluster" "main" { }          # Primary EKS cluster
resource "aws_security_group" "nlb" { }        # NLB security group
resource "aws_security_group" "eks_cluster" { } # EKS cluster security group
resource "aws_security_group" "internal" { }   # Internal service communication
resource "aws_s3_bucket" "artifacts" { }       # Artifacts storage
resource "aws_s3_bucket" "logs" { }            # Logs storage
resource "aws_route53_zone" "private" { }      # Private DNS zone

# ❌ AVOID - Inconsistent naming
resource "aws_lb" "this" { }           # Too generic
resource "aws_lb" "ddc_nlb" { }        # Module-specific
resource "aws_lb" "load_balancer" { }  # Verbose
```

### **Excellence Pattern: Provider Configurations**

**CRITICAL**: Modules should NOT define provider configurations - only version requirements.

**Required Versions (Universal):**
- **Terraform >= 1.11** - Required for enhanced testing framework and stability improvements
- **AWS Provider >= 6.0.0** - MANDATORY for enhanced region support in multi-region deployments

**Additional Providers (When Needed):**
- **Kubernetes Provider >= 2.33.0** - For modules using Kubernetes resources
- **Helm Provider >= 3.0.0** - For modules deploying Helm charts

```hcl
# ✅ EXCELLENT - Universal requirements
terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"  # CRITICAL for enhanced region support
    }
    # Add additional providers only when needed:
    # kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.33.0" }
    # helm = { source = "hashicorp/helm", version = ">= 3.0.0" }
  }
}
```

**Why AWS Provider v6.0.0+**: Enhanced region support allows automatic region inheritance for multi-region deployments, eliminating the need to explicitly pass AWS providers to submodules.

## 🔒 Security Standards

### **Excellence Pattern: User-Controlled Access**

```hcl
# ✅ EXCELLENT - Users control external access, we create internal communication
variable "existing_security_groups" {
  type        = list(string)
  description = "Security group IDs for external access"
  default     = []
}

# ✅ EXCELLENT - Internal communication security group
resource "aws_security_group" "internal" {
  name        = "${local.name_prefix}-internal"
  description = "Internal service communication"
  vpc_id      = var.existing_vpc_id

  # Internal service rules only
  ingress {
    from_port = 9042
    to_port   = 9042
    protocol  = "tcp"
    self      = true  # Only from same security group
  }

  # ✅ ACCEPTABLE - Outbound internet access for AWS APIs
  egress {
    description = "All outbound traffic (AWS APIs, updates, container registry)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Required for AWS API calls
  }
}

# ✅ EXCELLENT - Apply security groups with concat
resource "aws_eks_node_group" "main" {
  security_groups = concat(
    var.existing_security_groups,              # User-controlled
    var.existing_load_balancer_security_groups, # Component-specific
    [aws_security_group.internal.id]          # Internal communication
  )
}
```

### **Excellence Pattern: Security Validation**

```hcl
# ✅ EXCELLENT - Prevent insecure configurations
variable "allowed_external_cidrs" {
  type        = list(string)
  description = "CIDR blocks for external access"
  default     = []

  validation {
    condition     = !contains(var.allowed_external_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed for ingress. Specify actual CIDR blocks."
  }
}
```

### **Excellence Pattern: HTTPS-First Policy**

```hcl
# ✅ EXCELLENT - Certificate validation for internet-facing services
variable "existing_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listeners (required for internet-facing)"
  default     = null

  validation {
    condition = var.internet_facing == false || var.existing_certificate_arn != null || var.debug_mode == "enabled"
    error_message = "Certificate ARN required for internet-facing services unless debug_mode enabled"
  }
}

# ✅ EXCELLENT - HTTPS listener (production)
resource "aws_lb_listener" "https" {
  count             = var.existing_certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.nlb.arn
  port              = "443"
  protocol          = "TLS"
  certificate_arn   = var.existing_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ✅ EXCELLENT - HTTP redirect to HTTPS or debug mode
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type = var.debug_mode == "enabled" ? "forward" : (
      var.existing_certificate_arn != null ? "redirect" : "forward"
    )

    dynamic "redirect" {
      for_each = var.debug_mode == "disabled" && var.existing_certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.debug_mode == "enabled" || var.existing_certificate_arn == null ?
      aws_lb_target_group.main.arn : null
  }
}
```

## 🌐 DNS Standards

### **Excellence Pattern: Always Create Private Zones**

**Reasoning**: Private hosted zones provide essential internal service discovery, enable future multi-region replication, and support operational troubleshooting without additional cost. They're created automatically to ensure consistent DNS patterns across all modules.

**Note**: As with all standards, we evaluate exceptions on a case-by-case basis. If your specific use case doesn't benefit from private DNS, discuss with the team.

```hcl
# ✅ EXCELLENT - Always create private zone
resource "aws_route53_zone" "private" {
  name = var.existing_route53_public_hosted_zone_name != null ?
    "${var.project_prefix}.${var.existing_route53_public_hosted_zone_name}" :
    "${var.project_prefix}.internal"

  vpc {
    vpc_id = var.existing_vpc_id
  }
}

# ✅ EXCELLENT - Always create service records for internal discovery
resource "aws_route53_record" "scylla" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "scylla"
  type    = "A"
  ttl     = 300
  records = aws_instance.scylla[*].private_ip
}
```

### **Excellence Pattern: Regional Endpoint Pattern**

```hcl
# ✅ EXCELLENT - Multi-region DNS standard
locals {
  # Regional endpoint: {region}.{service}.{domain}
  public_dns_name = var.existing_route53_public_hosted_zone_name != null ?
    "${var.region}.${local.service_name}.${var.existing_route53_public_hosted_zone_name}" :
    null

  service_name = "ddc"  # or "perforce", "jenkins", etc.
}

# Examples:
# us-east-1.ddc.company.com
# us-west-2.ddc.company.com
# eu-west-1.perforce.company.com
```

## 🧪 Testing Standards

### **Excellence Pattern: Terraform Test Framework**

All modules must implement comprehensive testing using the Terraform Test Framework:

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
    existing_vpc_id = "vpc-12345678"
    existing_load_balancer_subnets = ["subnet-12345678"]
    existing_service_subnets = ["subnet-87654321"]
  }

  module {
    source = "./examples/complete"
  }
}
```

### **Excellence Pattern: Test Setup Directory**

```hcl
# tests/setup/ssm.tf - REQUIRED for all modules
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

## ✅ Excellence Checklists

### **For New Modules**
- [ ] Use `existing_` prefix for external resources
- [ ] Implement standardized logical names (nlb, alb, main, etc.)
- [ ] Create private DNS zones automatically
- [ ] Use random IDs for resource naming
- [ ] Implement HTTPS-first policy with debug exception
- [ ] Use tiered security group strategy
- [ ] Set conservative defaults
- [ ] Create comprehensive examples
- [ ] Add Terraform tests with setup/ directory
- [ ] Document architecture patterns
- [ ] Use examples for architecture decisions, not module variables

### **For Existing Modules Enhancement**
- [ ] Plan breaking changes for v2.0.0
- [ ] Add `moved` blocks for renamed resources
- [ ] Update variable naming conventions
- [ ] Implement DNS standards
- [ ] Add HTTPS enforcement
- [ ] Update security group patterns
- [ ] Create migration documentation
- [ ] Test upgrade paths with real state files

### **Security Excellence**
- [ ] No 0.0.0.0/0 ingress rules in module code
- [ ] Outbound 0.0.0.0/0 egress rules only for AWS APIs
- [ ] Use dedicated security group rule resources
- [ ] Implement certificate validation for internet-facing services
- [ ] Use user-provided security groups for external access
- [ ] Create internal security groups for service communication

### **Testing Excellence**
- [ ] All modules have Terraform Test Framework tests
- [ ] Tests use setup/ directory for SSM parameter retrieval
- [ ] Both unit tests (plan) and integration tests (apply)
- [ ] All tests pass before PR approval
- [ ] Tests reference examples, not module directly

## 📚 Architecture Guidance

**Note**: These are our **recommended patterns and preferences**, not hard requirements for every module. Networking configurations should be defined at the example level to maintain module flexibility.

### **Recommended Compute Strategy**
1. **Serverless** (Lambda, Fargate) - Preferred for simplicity and cost
2. **Managed Containers** (ECS Fargate, EKS Fargate) - For scalable services
3. **Container Orchestration** (ECS EC2, EKS EC2) - When Fargate limitations apply
4. **Dedicated EC2** - Only when technology requirements mandate it

### **Recommended Networking Patterns**

**Note**: Networking decisions should be made at the **example level**, not enforced by modules. These are recommended patterns that examples can demonstrate.

**External Access Pattern (Example-Driven):**
```
Internet Users → Public NLB → NLB Target (EKS, EC2, etc.)
```

**External Access with ALB (When HTTP Routing Needed):**
```
Internet Users → Public NLB → ALB → Service Targets (EKS Pods, EC2, etc.)
```

**Internal Access Pattern (Example-Driven):**
```
VPN/VDI Users → Private NLB → NLB Target (ALB, EKS, EC2, etc.)
```

**VPC Endpoints**: Currently not supported but under consideration. If you're interested in VPC Endpoints support, please [submit a feature request](https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=enhancement&template=feature_request.md) to the toolkit.

### **Excellence Pattern: Multi-Region Architecture**

**Regional Isolation Pattern:**
- **Separate module instances** per region
- **Regional endpoints** for user control
- **Manual disaster recovery** (users switch endpoints)
- **Cross-region connectivity** via VPC peering or Transit Gateway

**AWS Provider v6 Enhanced Region Support:**
We leverage Terraform's enhanced AWS provider region support for multi-region deployments. AWS Provider v6+ automatically handles region inheritance, reducing provider configuration complexity.

```hcl
# ✅ EXCELLENT - Enhanced region support (AWS Provider v6+)
module "ddc_primary" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc?ref=v1.2.0"

  # Enhanced region support - AWS provider auto-inherited
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
    # AWS provider automatically inherited based on region
  }

  region = var.primary_region
  existing_vpc_id = aws_vpc.primary.id

  ddc_infra_config = {
    region = var.primary_region
    create_seed_node = true
    # Primary region configuration...
  }
}

# Secondary region
module "ddc_secondary" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc?ref=v1.2.0"

  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
    # AWS provider automatically inherited based on region
  }

  region = var.secondary_region
  existing_vpc_id = aws_vpc.secondary.id

  ddc_infra_config = {
    region = var.secondary_region
    create_seed_node = false
    existing_scylla_seed = module.ddc_primary.ddc_infra.scylla_seed
    # Secondary region configuration...
  }

  ddc_services_config = {
    ddc_replication_region_url = module.ddc_primary.ddc_connection.endpoint_nlb
    # Replication configuration...
  }

  depends_on = [module.ddc_primary]
}
```

**Benefits**: AWS Provider v6 automatically handles region inheritance, reducing provider configuration complexity. Other providers (Kubernetes, Helm) still require explicit provider configuration until they adopt enhanced region support.

### **Breaking Changes Prevention**

**Excellence Rules:**
- **✅ ALWAYS use major version bumps** for breaking changes
- **✅ ALWAYS test migration paths** with real state files
- **✅ ALWAYS document breaking changes** comprehensively
- **❌ NEVER change logical names** without `moved` blocks
- **❌ NEVER change variable names** in minor/patch versions

**Safe Enhancement Patterns:**
```hcl
# ✅ SAFE - Adding new resources
resource "aws_s3_bucket" "new_bucket" {
  bucket = "${var.name_prefix}-new-bucket"
}

# ✅ SAFE - Adding optional variables with defaults
variable "new_feature_enabled" {
  type        = bool
  description = "Enable new feature"
  default     = false  # REQUIRED default
}

# ✅ SAFE - Adding new outputs
output "new_resource_id" {
  value = aws_s3_bucket.new_bucket.id
}
```

## 🚀 Getting Started

1. **Review Gold Standards** - Understand what excellence looks like
2. **Choose Module Structure** - Simple parent module or justified submodules
3. **Implement Naming Standards** - Variables, resources, and logical names
4. **Add Security Patterns** - HTTPS-first, user-controlled access
5. **Create DNS Infrastructure** - Private zones and regional endpoints
6. **Build Comprehensive Tests** - Unit and integration tests with setup/
7. **Document with Examples** - Show architecture decisions in examples
8. **Validate Excellence** - Use checklists to ensure compliance

For questions or clarifications on these standards, please engage with the team through GitHub discussions or issues.
