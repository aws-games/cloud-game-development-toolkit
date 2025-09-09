# CGD Toolkit Module Design Standards

## Overview

This document captures the design decisions and patterns we've collectively agreed upon for CGD Toolkit modules. These standards emerged from real-world usage, community feedback, and lessons learned from building production game development infrastructure.

**Why These Standards Matter**: As CGD Toolkit grows, consistency becomes critical for maintainability, user experience, and contributor onboarding. These patterns represent our best practices for building reliable, secure, and user-friendly Terraform modules.

**Living Document**: These standards evolve based on community needs and new AWS capabilities. When proposing changes, consider backward compatibility and migration paths for existing users.

**Module Evolution**: You might find some modules that don't follow these patterns yet - they're likely on our refactoring roadmap. If you spot a recently updated module that diverges from these standards, let us know! We're always improving and appreciate the feedback.

## Core Design Philosophy

### **1. Readability First**
**Why**: Game development teams often include infrastructure newcomers. Clear, understandable code reduces onboarding time and prevents misconfigurations.

- Prefer explicit over implicit configurations
- Use descriptive variable names that explain purpose
- Self-documenting code over clever abstractions
- Comment complex logic with business context

### **2. Flexibility Through Modularity**
**Why**: Game studios have diverse infrastructure needs. Rigid, opinionated modules force workarounds and reduce adoption.

- Modules provide building blocks, not complete solutions
- Configuration decisions happen in examples, not module internals
- Support multiple deployment patterns through simple variables
- Enable customization without requiring module forking

### **3. Conservative Variable Exposure**
**Why**: Every exposed variable is a commitment to backward compatibility. We learned this from early modules that exposed too many options.

- Start with minimal variables based on known use cases
- Add variables when users request them (demand-driven)
- Easier to add than remove (breaking changes are painful)
- Default values should work for 80% of use cases

### **4. Security by Default**
**Why**: Game development infrastructure often handles sensitive assets and player data. Security mistakes are costly and hard to fix later.

- No 0.0.0.0/0 ingress rules in module code (unless you have a ***really*** good reason - we will ask) - [more details](#security-patterns)
- Users explicitly define allowed access (security groups, CIDRs)
- Private-first architecture with controlled external access
- HTTPS enforcement for internet-facing services

## Module Architecture

### **Directory Structure**
```
modules/service-name/
├── main.tf              # Parent module orchestration
├── variables.tf         # Input variables with validation
├── outputs.tf           # Module outputs
├── versions.tf          # Terraform and provider version constraints
├── README.md            # Module documentation
├── modules/             # Submodules (when needed)
│   ├── infra/          # AWS resources only
│   └── services/       # Kubernetes/Helm only
├── tests/              # Terraform tests
│   ├── setup/          # CI parameter retrieval
│   └── *.tftest.hcl    # Test files
└── examples/           # Working examples
    └── */              # Example configurations
```

### **Parent Module Pattern**
**Why**: When modules have submodules, the parent focuses on user experience while submodules handle implementation details.

**Responsibilities**:
- Create some resources directly (DNS zones, security groups, etc.)
- Provide clean, user-friendly variable interface
- Validate inputs with helpful error messages
- Orchestrate submodules with proper dependencies (when present)
- Expose essential outputs for downstream usage

### **When to Use Submodules**
**Why Split**: Provider separation or complexity management.

```hcl
# ✅ GOOD - Different providers
module "infra" {
  source = "./modules/infra"
  providers = { aws = aws }
}

module "services" {
  source = "./modules/services"
  providers = { kubernetes = kubernetes, helm = helm }
  depends_on = [module.infra]
}

# ❌ AVOID - Same provider, no clear benefit
module "s3_bucket" {
  source = "./modules/s3"
}
```

### **Submodule Variable Alignment Pattern**
**When using submodules, align parent variables directly to submodules for clarity:**

```hcl
# ✅ GOOD - Clear submodule alignment
variable "infra_config" {
  type = object({
    # All infrastructure settings grouped together
    kubernetes_version = optional(string, "1.33")
    database_config = object({...})
    networking_config = object({...})
  })
}

variable "services_config" {
  type = object({
    # All service settings grouped together
    app_version = optional(string, "latest")
    credentials_arn = string
  })
}

# Parent module orchestration
module "infra" {
  source = "./modules/infra"
  config = var.infra_config  # Direct alignment
}

module "services" {
  source = "./modules/services"
  config = var.services_config  # Direct alignment
}

# ❌ AVOID - Scattered variables requiring manual mapping
variable "kubernetes_version" { }
variable "database_instance_type" { }
variable "app_version" { }
variable "credentials_arn" { }

module "infra" {
  kubernetes_version = var.kubernetes_version
  database_instance_type = var.database_instance_type
  # Manual mapping of many variables
}
```

**Benefits of Submodule Alignment:**
- **Clear responsibility** - Users understand which settings affect which components
- **Easy orchestration** - Parent module passes entire objects to submodules
- **Conditional creation** - `config = null` skips entire submodules
- **Reduced complexity** - No manual variable mapping in parent module
- **Logical grouping** - Related settings stay together

## Networking Standards

### **Access Patterns**
**CGD Toolkit modules support three standardized access patterns:**
- **Internet-Accessible** - Public services (DDC, Perforce, Jenkins) with controlled external access
- **VPC-Only** - Internal services (Databases, Monitoring) accessible only within VPC
- **Mixed** - Services with both public and private components

### **Load Balancer Strategy**
**Consistent approach across all modules:**
- **Default to NLB** for most services (connection-level health checks, static IPs, predictable routing)
- **ALB when needed** for HTTP/HTTPS routing, WAF integration, path-based routing
- **User controls creation** via boolean flags or configuration objects
- **Automatic target group management** - modules handle the complexity
- **Cost justified** - ~$16/month NLB vs Route53 health check complexity

### **DNS Patterns**
**Regional endpoints by default following AWS service patterns:**
- **Regional endpoints** - `us-east-1.service.company.com` (performance, isolation, explicit control)
- **Private zones** - Always created for internal service discovery (`service.internal`)
- **Global endpoints** - Optional for advanced routing (latency-based, geolocation, failover)
- **DNS hierarchy** - `region.cluster.platform.service.domain` for complex services

### **Variable Structure Philosophy**
**Hybrid approach following popular module patterns:**
- **Flat variables** for simple, common settings (following terraform-aws-modules pattern)
- **Complex objects** for logical grouping when they provide clear value (following AWS-IA pattern)
- **Submodule alignment** - Complex objects that map directly to submodules (`infra_config`, `services_config`)
- **Component objects acceptable** - `load_balancer_config`, `security_groups` for logical grouping
- **Conditional creation** - `config = null` skips entire components
- **Intelligent defaults** - Work for 80% of use cases, reduce cognitive load

### **Security Group Integration**
**Follow Terraform resource patterns for familiarity:**
- **User-controlled external access** - Users provide security groups with their own rules
- **Module-created internal groups** - For service-to-service communication
- **Component-specific grouping** - General + NLB-specific + ALB-specific
- **CIDR validation** - No 0.0.0.0/0 ingress rules in module code

## Variable Design Patterns

### **General Naming Conventions**
**Why Descriptive Names**: We avoid generic names like `this` because they don't scale and become confusing when you need multiple resources.

```hcl
# ✅ GOOD - Descriptive, purpose-driven names
resource "aws_lb" "nlb" { }                    # Network Load Balancer
resource "aws_lb" "alb" { }                    # Application Load Balancer
resource "aws_eks_cluster" "main" { }          # Primary EKS cluster
resource "aws_security_group" "nlb" { }        # NLB security group
resource "aws_security_group" "internal" { }   # Internal communication
resource "aws_s3_bucket" "artifacts" { }       # Artifacts storage
resource "aws_s3_bucket" "logs" { }            # Logs storage
resource "aws_route53_zone" "private" { }      # Private DNS zone

# ❌ BAD - Generic names that don't scale
resource "aws_lb" "this" { }           # What kind of load balancer?
resource "aws_lb" "this2" { }          # Now you need a second one...
resource "aws_s3_bucket" "bucket" { }  # What's it for?
resource "aws_s3_bucket" "main" { }    # Still not descriptive
```

**The Problem with Generic Names**:
- **Not descriptive**: `this` tells you nothing about purpose
- **Doesn't scale**: Need a second resource? Now it's `this2` or you rename everything
- **Hard to reference**: `aws_lb.this.dns_name` - which load balancer?
- **Confusing in outputs**: `nlb_dns_name = aws_lb.this.dns_name` - misleading

**Our Standard Logical Names**:
- **`nlb`**: Network Load Balancer
- **`alb`**: Application Load Balancer  
- **`main`**: Primary resource of its type (EKS cluster, VPC)
- **`internal`**: Internal communication security group
- **`artifacts`**: Artifact storage bucket
- **`logs`**: Logging storage bucket
- **`private`**: Private DNS zone

### **3-Tier Architecture**
**Why**: Users consistently need to separate applications, supporting services, and load balancers.

```hcl
variable "application_subnets" {
  type        = list(string)
  description = "Subnets for primary business applications"
}

variable "service_subnets" {
  type        = list(string)
  description = "Subnets for supporting services (databases, caches)"
  default     = []  # Uses application_subnets if not specified
}

variable "load_balancer_config" {
  type = object({
    nlb = object({
      enabled         = optional(bool, true)
      internet_facing = optional(bool, true)
      subnets        = list(string)
    })
    alb = optional(object({
      enabled         = optional(bool, false)
      internet_facing = optional(bool, true)
      subnets        = list(string)
      enable_waf     = optional(bool, false)
    }), null)
  })
}
```

### **Security Group Strategy**
```hcl
variable "security_groups" {
  type        = list(string)
  description = "Security group IDs for external access"
  default     = []
}

variable "additional_security_groups" {
  type = object({
    load_balancer = optional(list(string), [])
    eks_cluster   = optional(list(string), [])
  })
  description = "Component-specific security groups"
  default     = {}
}
```

## Resource Patterns

### **Remote Module Usage Philosophy**
**CGD Toolkit modules prefer direct resources over remote module dependencies.**

#### **Default Approach: Direct Resources**
**Start with direct AWS resources unless there's a compelling reason for a module:**

```hcl
# ✅ PREFERRED - Direct resource creation
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version
  
  vpc_config {
    subnet_ids              = var.existing_service_subnets
    endpoint_private_access = var.eks_cluster_private_access
    endpoint_public_access  = var.eks_cluster_public_access
    public_access_cidrs     = var.eks_cluster_public_access_cidrs
  }
  
  # Direct configuration gives us full control
}

# ❌ AVOID - Remote module dependency
module "eks" {
  source = "registry.terraform.io/example/eks/aws"
  # Adds complexity, version dependencies, limited customization
}
```

#### **When Remote Modules Add Complexity**
**Common issues we've encountered with remote modules:**

- **Version conflicts**: Remote modules pin provider versions that conflict with our requirements
- **Limited customization**: Remote modules don't expose the exact configuration we need
- **Bug dependencies**: Waiting for upstream fixes when we could implement directly
- **Breaking changes**: Remote module updates can break our implementations
- **Debugging difficulty**: Issues span multiple codebases and maintainers
- **Documentation gaps**: Remote module docs may not cover our specific use cases

#### **Acceptable Remote Module Usage**
**Use remote modules only when there's clear benefit:**

```hcl
# ✅ ACCEPTABLE - Well-established, stable modules with clear benefits
module "eks_addons" {
  source = "registry.terraform.io/example/eks-addons/aws"
  version = "~> 2.0"
  
  # Only when:
  # 1. Module is extremely stable and well-maintained
  # 2. Provides significant complexity reduction
  # 3. Benefits clearly outweigh the added complexity
  # 4. Direct implementation would be overly complex
}
```

**Criteria for acceptable remote module usage:**
- **Stability**: Module has long track record of stability
- **Maintenance**: Active maintenance and responsive maintainers
- **Customization**: Exposes all configuration we need
- **Complexity reduction**: Significantly reduces code complexity
- **Clear benefit**: Pros outweigh cons in terms of complexity it helps resolve

#### **Fork-First Strategy**
**When you need a remote module, fork it first:**

```hcl
# ✅ RECOMMENDED - Fork and customize
module "custom_component" {
  source = "./modules/forked-module"  # Local fork
  
  # Benefits:
  # - Full control over changes
  # - No waiting for upstream fixes
  # - Can customize for our specific needs
  # - No external version dependencies
}

# ❌ AVOID - Direct remote dependency
module "component" {
  source = "github.com/example/external-module"
  # Creates external dependency and limits our control
}
```

**Fork-first benefits:**
- **Immediate fixes**: Fix bugs without waiting for upstream
- **Custom features**: Add CGD Toolkit-specific functionality
- **Version control**: No external version dependency conflicts
- **Stability**: Changes only when we decide to update
- **Documentation**: We can document our specific usage patterns

#### **Implementation Guidelines**

##### **For New Modules**
1. **Start with direct resources**: Always begin with AWS resources directly
2. **Evaluate complexity**: Only consider modules if direct implementation is extremely complex
3. **Fork if needed**: If you must use a remote module, fork it first
4. **Document decision**: Explain why direct resources weren't sufficient

##### **For Existing Modules**
1. **Audit dependencies**: Review existing remote module usage
2. **Plan replacement**: Create plan to replace with direct resources
3. **Gradual migration**: Replace remote modules incrementally
4. **Test thoroughly**: Ensure functionality remains identical

##### **Code Review Checklist**
**When reviewing PRs that add remote modules:**

- [ ] **Justification provided**: Clear explanation why direct resources aren't sufficient
- [ ] **Alternatives explored**: Evidence that direct implementation was considered
- [ ] **Fork strategy**: If remote module needed, is it forked locally?
- [ ] **Stability assessment**: Is the remote module well-maintained and stable?
- [ ] **Customization needs**: Does the module expose all needed configuration?
- [ ] **Version pinning**: Are versions properly pinned to avoid surprises?

#### **Examples of Our Approach**

##### **EKS Cluster Creation**
```hcl
# We use direct resources instead of remote EKS modules
resource "aws_eks_cluster" "main" {
  # Direct control over all EKS configuration
}

resource "aws_eks_node_group" "main" {
  # Direct control over node group settings
}

# Why: Remote EKS modules often don't expose the exact configuration we need
# for game development workloads
```

##### **Acceptable Remote Module Usage in Core Modules**
```hcl
# Example: EKS add-ons where complexity reduction justifies remote module
module "eks_addons" {
  source = "registry.terraform.io/example/eks-addons/aws"
  
  # Why acceptable:
  # - Handles complex EKS add-on lifecycle management
  # - Significantly reduces implementation complexity
  # - Well-maintained with responsive maintainers
  # - Benefits clearly outweigh the dependency costs
}

# We still prefer direct resources for core EKS cluster
resource "aws_eks_cluster" "main" {
  # Direct control for primary resources
}
```

##### **VPC Usage in Examples**
```hcl
# In examples, we may use well-established modules for convenience
module "vpc" {
  source = "registry.terraform.io/example/vpc/aws"
  # Acceptable in examples for user convenience
  # Users can replace with their own VPC implementation
}
```

#### **Migration Strategy**
**For modules currently using remote dependencies:**

1. **Identify usage**: Audit current remote module usage
2. **Assess impact**: Determine complexity of direct implementation
3. **Create timeline**: Plan gradual migration to direct resources
4. **Maintain compatibility**: Ensure variable interfaces remain stable
5. **Document changes**: Update examples and documentation

**This approach ensures:**
- **Full control**: We control all aspects of resource creation
- **Faster iteration**: No waiting for upstream changes
- **Reduced complexity**: Fewer dependencies to manage
- **Better debugging**: All code is within our control
- **Customization freedom**: Can modify resources for game development needs

### **Centralized Logging Design Patterns**
**CGD Toolkit modules standardize on centralized logging for visibility and troubleshooting.**

#### **Logging Philosophy**
**All modules provide optional centralized logging with intelligent categorization:**

- **User controlled**: Users can enable as much logging as desired for maximum visibility
- **CloudWatch standardization**: Native AWS logging service as the foundation
- **Monitoring flexibility**: Any monitoring solution that supports CloudWatch Logs can be used
- **Intelligent categorization**: Logs grouped by infrastructure, application, and service layers
- **Cost conscious**: Configurable retention periods with sensible defaults
- **Security by default**: Proper IAM permissions and encryption

**Why CloudWatch Logs**: We standardize on CloudWatch Logs as the native AWS logging service. From there, customers can integrate with any monitoring solution they prefer - Grafana, Datadog, Splunk, New Relic, or custom solutions. This approach provides maximum flexibility while ensuring consistent log collection.

#### **Three-Tier Logging Structure**
**Logs are categorized into three distinct tiers:**

##### **Infrastructure Logs**
**AWS managed services and infrastructure components:**

```hcl
# Infrastructure category maps to AWS services
infrastructure = {
  "nlb" = {}     # Network Load Balancer access logs
  "alb" = {}     # Application Load Balancer access logs  
  "eks" = {}     # EKS control plane logs
  "rds" = {}     # RDS database logs (when applicable)
}
```

**Examples by module:**
- **DDC Module**: NLB access logs, EKS control plane logs
- **Perforce Module**: NLB/ALB access logs, EKS control plane logs, RDS logs
- **Jenkins Module**: ALB access logs, EKS control plane logs

##### **Application Logs**
**Core business logic of the primary application:**

```hcl
# Application category maps to primary service
application = {
  "ddc" = {}       # DDC service logs (DDC module)
  "perforce" = {}  # Perforce server logs (Perforce module)
  "jenkins" = {}   # Jenkins controller logs (Jenkins module)
}
```

**Examples:**
- **DDC**: Unreal Cloud DDC application pod logs
- **Perforce**: P4D server logs, Helix Core logs
- **Jenkins**: Jenkins controller and agent logs

##### **Service Logs**
**Supporting services that enable the primary application:**

```hcl
# Service category maps to supporting components
service = {
  "scylla" = {}    # ScyllaDB database logs (DDC module)
  "p4-auth" = {}   # Perforce authentication service (Perforce module)
  "p4-review" = {} # Perforce code review service (Perforce module)
}
```

**Examples:**
- **DDC**: ScyllaDB database logs
- **Perforce**: P4-auth service, P4-code-review service
- **Jenkins**: Supporting databases, caches, or queues

#### **Standard Logging Variable Pattern**
**All modules implement consistent logging configuration:**

```hcl
variable "centralized_logging" {
  type = object({
    infrastructure = optional(map(object({
      enabled        = optional(bool, true)
      retention_days = optional(number, 90)
    })), {})
    application = optional(map(object({
      enabled        = optional(bool, true)
      retention_days = optional(number, 30)
    })), {})
    service = optional(map(object({
      enabled        = optional(bool, true)
      retention_days = optional(number, 60)
    })), {})
    log_group_prefix = optional(string, null)
  })
  
  description = "Centralized logging configuration by category"
  default = null
}
```

#### **Log Group Naming Convention**
**Consistent naming across all modules:**

```hcl
# Pattern: {log_group_prefix}/{category}/{component}
# Default prefix: "{project_prefix}-{service_name}-{region}"

# Examples:
# cgd-unreal-cloud-ddc-us-east-1/infrastructure/nlb
# cgd-unreal-cloud-ddc-us-east-1/application/ddc
# cgd-unreal-cloud-ddc-us-east-1/service/scylla

# cgd-perforce-us-west-2/infrastructure/alb
# cgd-perforce-us-west-2/application/perforce
# cgd-perforce-us-west-2/service/p4-auth
```

#### **Usage Examples**

##### **Enable All Logging with Defaults**
```hcl
module "ddc" {
  centralized_logging = {
    infrastructure = { nlb = {}, eks = {} }
    application    = { ddc = {} }
    service        = { scylla = {} }
  }
}
```

##### **Custom Retention and Prefix**
```hcl
module "perforce" {
  centralized_logging = {
    infrastructure = { 
      nlb = { retention_days = 365 }
      alb = { retention_days = 180 }
      eks = { retention_days = 90 }
    }
    application = { 
      perforce = { retention_days = 60 }
    }
    service = { 
      "p4-auth" = { retention_days = 30 }
      "p4-review" = { retention_days = 30 }
    }
    log_group_prefix = "mycompany-perforce-prod"
  }
}
```

##### **Selective Logging**
```hcl
module "jenkins" {
  centralized_logging = {
    infrastructure = { 
      alb = { enabled = false }  # Disable ALB logging
      eks = {}                   # Enable EKS logging only
    }
    application = { jenkins = {} }
    # No service logging needed for this deployment
  }
}
```

#### **Default Retention Periods**
**Cost-optimized defaults based on log type:**

- **Infrastructure**: 90 days (AWS service troubleshooting)
- **Application**: 30 days (balance between debugging and cost)
- **Service**: 60 days (database analysis and performance tuning)

#### **Module-Specific Logging Patterns**
**Not all modules fit the standard 3-tier structure. Modules should only create log groups for components they actually have.**

##### **Single Category Pattern (VDI Module Example)**
**When modules have simple architectures where everything happens in one place:**

```hcl
# VDI Module - Single log group for all activities
resource "aws_cloudwatch_log_group" "vdi_logs" {
  name = "/${var.project_prefix}/vdi/logs"
  # All VDI activity: SSM execution, user creation, DCV sessions, software installation
}
```

**Use single category when:**
- All functionality runs on same compute (EC2 instances)
- SSM-based architecture where everything logs to same destination
- No separate infrastructure services to log
- Simpler structure matches module reality

##### **Standard 3-Tier Pattern (DDC/Perforce Module Example)**  
**When modules have distinct infrastructure, application, and service components:**

```hcl
# Standard pattern for complex modules
infrastructure = { "nlb" = {}, "eks" = {} }
application    = { "ddc" = {} }  
service        = { "scylla" = {} }
```

**Principle**: Match logging structure to module architecture, not arbitrary standards.

#### **Implementation Requirements**
**All modules must implement:**

- **CloudWatch Log Groups**: Created for each enabled component
- **Proper IAM permissions**: Services can write to their log groups
- **S3 integration**: Long-term storage with lifecycle policies
- **Encryption**: Log groups encrypted with appropriate KMS keys
- **Validation**: Only supported components allowed per module
- **Documentation**: Clear explanation of what each component logs

#### **Component Validation**
**Modules validate only supported components:**

```hcl
# Each module validates its specific supported components
validation {
  condition = alltrue([
    # Infrastructure: only components this module actually creates
    alltrue([
      for component in keys(var.centralized_logging.infrastructure) :
      contains(["nlb", "eks"], component)  # DDC module example
    ]),
    # Application: only the primary service
    alltrue([
      for component in keys(var.centralized_logging.application) :
      contains(["ddc"], component)  # DDC module example
    ]),
    # Service: only supporting services this module deploys
    alltrue([
      for component in keys(var.centralized_logging.service) :
      contains(["scylla"], component)  # DDC module example
    ])
  ])
  error_message = "Unsupported logging component specified for this module."
}
```

#### **Cost Considerations**
**Logging configuration balances visibility with cost:**

- **Shorter retention = lower costs**: Adjust based on compliance needs
- **Selective enablement**: Disable non-critical logging in development
- **S3 lifecycle policies**: Automatic transition to cheaper storage classes
- **Log sampling**: Consider sampling for high-volume logs

#### **Security and Compliance**
**All logging implementations include:**

- **Encryption at rest**: CloudWatch logs encrypted with KMS
- **IAM least privilege**: Services only access their specific log groups
- **VPC Flow Logs**: Optional for network troubleshooting
- **Audit trails**: CloudTrail integration for API calls
- **Data retention**: Configurable retention for compliance requirements

#### **Future: CGD Toolkit Monitoring Module**
**We're actively developing a comprehensive monitoring module:**

- **Amazon Managed Grafana**: Dashboard solution consuming CloudWatch Logs
- **Game tooling infrastructure**: Monitor VDI instances, Perforce, DDC, Jenkins, and more
- **Multi-region support**: Unified monitoring across all regional deployments
- **Optional integration**: Use with any CGD Toolkit modules that have logging enabled
- **No ETA yet**: Still in development, but will leverage our CloudWatch Logs foundation

**Design principle**: Since all CGD Toolkit modules send logs to CloudWatch Logs when enabled, any monitoring solution that supports CloudWatch integration can be used - whether it's our future monitoring module, Amazon Managed Grafana, Datadog, Splunk, or custom solutions.

**This standardized approach provides:**
- **Maximum visibility**: Users control how much logging they want enabled
- **Consistent logging**: Same patterns across all CGD Toolkit modules
- **Monitoring flexibility**: Works with any CloudWatch-compatible monitoring solution
- **Operational visibility**: Comprehensive logging for troubleshooting
- **Cost control**: Configurable retention and selective enablement
- **Security compliance**: Proper encryption and access controls
- **Future-ready**: Foundation for CGD Toolkit monitoring module and other solutions

### **Naming Strategy**
**Why**: AWS services have different naming patterns when using prefixes. Our approach provides predictable, referenceable names.

```hcl
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
  
  # Predictable names across all resources
  nlb_name    = "${local.name_prefix}-nlb-${local.name_suffix}"
  bucket_name = "${local.name_prefix}-logs-${local.name_suffix}"
}
```

### **Load Balancer Philosophy**
**Why**: Game services often need Layer 4 (NLB) for performance. ALB adds value for HTTP/HTTPS routing scenarios.

- **NLB**: Always available, required for most modules
- **ALB**: Optional, module-specific validation prevents unsupported usage

### **DNS Patterns**
**Why Regional**: Like AWS services, we default to regional endpoints for performance, isolation, and explicit control.

```hcl
# Regional endpoints (our default)
# us-east-1.ddc.company.com
# us-west-2.ddc.company.com

# Users can add global endpoints for DR/geolocation
# ddc.company.com -> failover routing to regional endpoints
```

## Security Patterns

### **The 0.0.0.0/0 Rule**

#### **Ingress (Incoming) - Avoid 0.0.0.0/0**
**Risk**: 🔴 **HIGH** - Direct attack surface

```hcl
# ❌ DANGEROUS
resource "aws_vpc_security_group_ingress_rule" "bad" {
  cidr_ipv4 = "0.0.0.0/0"  # Opens to entire internet
}

# ✅ USER CONTROLLED
# Users provide security groups with their own rules
```

#### **Egress (Outgoing) - Often Necessary**
**Risk**: 🟡 **MEDIUM** - Controlled by application

```hcl
# ✅ NECESSARY for AWS APIs, updates, container registries
resource "aws_vpc_security_group_egress_rule" "aws_apis" {
  cidr_ipv4 = "0.0.0.0/0"
  description = "AWS APIs, ECR, OS updates"
}
```

### **Implementation Pattern**
```hcl
# We create internal security groups
resource "aws_security_group" "internal" {
  name_prefix = "${local.name_prefix}-internal-"
  vpc_id      = var.vpc_id
}

# Users control external access
resource "aws_lb" "nlb" {
  security_groups = concat(
    var.security_groups,                           # User-controlled
    var.additional_security_groups.load_balancer, # Component-specific
    [aws_security_group.internal.id]              # Internal
  )
}
```

## Provider Patterns

### **Provider Strategy: Root vs Parent vs Submodules**
**Why This Matters**: Provider configuration depends on where Terraform runs and how modules are consumed.

**Module Consumption**: We assume users will reference CGD modules remotely via Git URLs, but they could also clone/fork the toolkit and deploy from examples directories directly.

#### **Root Module (Where `terraform init` Runs)**
**Scenario**: Users run Terraform commands here - examples, user's own infrastructure

```hcl
# examples/single-region-basic/versions.tf
terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = ">= 6.0.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.33.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.16.0, < 3.0.0" }
  }
}

# examples/single-region-basic/providers.tf (when needed)
provider "kubernetes" {
  host = module.ddc.cluster_endpoint
  cluster_ca_certificate = base64decode(module.ddc.cluster_ca_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command = "aws"
    args = ["eks", "get-token", "--cluster-name", module.ddc.cluster_name]
  }
}
```

#### **Parent Module (CGD Toolkit Modules)**
**Scenario**: CGD Toolkit modules that both create resources AND orchestrate submodules when needed

**Single Region (Simple)**:
```hcl
# modules/unreal-cloud-ddc/main.tf
# Parent module creates some resources directly AND orchestrates submodules
# Parent module receives providers from root module

# Direct resource creation
resource "aws_route53_zone" "private" {
  name = "${var.project_prefix}.internal"
  vpc {
    vpc_id = var.vpc_id
  }
}

# Submodule orchestration

module "infra" {
  source = "./modules/infra"
  providers = { aws = aws }  # Pass from root (uses default or v6 region)
}

module "services" {
  source = "./modules/services"
  providers = { kubernetes = kubernetes, helm = helm }  # Pass from root
  depends_on = [module.infra]
}
```

**Multi-Region (Complex)**:
```hcl
# Root module: examples/multi-region/main.tf
# User must handle multi-region complexity at root level

# AWS Provider v6 - No aliases needed!
module "ddc_us_east_1" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc"
  region = "us-east-1"  # AWS Provider v6 handles this automatically
  
  # Non-enhanced providers need explicit aliases
  providers = {
    kubernetes = kubernetes.us_east_1
    helm       = helm.us_east_1
  }
}

module "ddc_us_west_2" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc"
  region = "us-west-2"  # AWS Provider v6 handles this automatically
  
  # Non-enhanced providers need explicit aliases  
  providers = {
    kubernetes = kubernetes.us_west_2
    helm       = helm.us_west_2
  }
}

# Root module must define all provider aliases
provider "kubernetes" {
  alias = "us_east_1"
  host = module.ddc_us_east_1.cluster_endpoint
  # ... configuration
}

provider "kubernetes" {
  alias = "us_west_2"
  host = module.ddc_us_west_2.cluster_endpoint
  # ... configuration
}
```

#### **Submodules**
**Scenario**: Receive providers from parent, use specific provider family

```hcl
# modules/unreal-cloud-ddc/modules/infra/main.tf
# Uses AWS provider passed from parent
resource "aws_eks_cluster" "main" { }

# modules/unreal-cloud-ddc/modules/services/main.tf  
# Uses Kubernetes/Helm providers passed from parent
resource "helm_release" "ddc" { }
```

### **Provider Value Sourcing Strategies**
**Why This Matters**: Providers need configuration values, but the source depends on timing and dependencies.

#### **Option 1: Data Sources (Independent Resources)**
**When**: Referencing existing, independent infrastructure

```hcl
# Root module: examples/existing-cluster/providers.tf
data "aws_eks_cluster" "existing" {
  name = var.existing_cluster_name
}

data "aws_eks_cluster_auth" "existing" {
  name = var.existing_cluster_name
}

provider "kubernetes" {
  host = data.aws_eks_cluster.existing.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
  token = data.aws_eks_cluster_auth.existing.token
}
```

#### **Option 2: Module Outputs (Dependent Resources)**
**When**: Module creates the infrastructure that providers need

```hcl
# Root module: examples/single-region-basic/providers.tf
provider "kubernetes" {
  host = module.ddc.cluster_endpoint
  cluster_ca_certificate = base64decode(module.ddc.cluster_ca_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command = "aws"
    args = ["eks", "get-token", "--cluster-name", module.ddc.cluster_name]
  }
}
```

#### **Option 3: Static/Hardcoded Values**
**When**: Known, unchanging values (rare, mostly for testing)

```hcl
# Root module: tests/setup/providers.tf
provider "kubernetes" {
  host = "https://test-cluster.example.com"
  token = var.test_cluster_token  # From CI secrets
}
```

### **Conditional Provider Configuration**
**Why This Matters**: Provider configurations are evaluated during every plan/apply. Understanding when to use `try()` vs explicit null checks is critical.

#### **Use `try()` for Data Sources**
**Why**: Prevents plan failures when resources don't exist yet.

```hcl
# ✅ RECOMMENDED - Graceful handling of missing resources
data "aws_eks_cluster" "existing" {
  count = var.cluster_name != null ? 1 : 0
  name  = var.cluster_name
}

provider "kubernetes" {
  # try() handles both missing data source AND missing attributes
  host = try(data.aws_eks_cluster.existing[0].endpoint, null)
  cluster_ca_certificate = try(
    base64decode(data.aws_eks_cluster.existing[0].certificate_authority[0].data),
    null
  )
}
```

#### **Use Explicit Null Checks for Module Outputs (CGD Toolkit Pattern)**
**Why**: Clearer dependency logic and better debugging.

```hcl
# ✅ RECOMMENDED - Clear dependency logic
provider "kubernetes" {
  host = module.infra.cluster_endpoint != null ? 
    module.infra.cluster_endpoint : null
  cluster_ca_certificate = module.infra.cluster_ca_data != null ? 
    base64decode(module.infra.cluster_ca_data) : null
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command = "aws"
    args = ["eks", "get-token", "--cluster-name", module.infra.cluster_name]
  }
}
```

### **Multi-Region: Global Replication Architecture**

#### **Standard Terraform Multi-Region Patterns**
**How most Terraform users handle multi-region deployments:**

##### **Pattern A: Monorepo Regional Structure (Less Recommended)**
**One Git repository per AWS region containing ALL applications:**
```
company-infrastructure-us-east-1/
├── networking/
├── databases/
├── applications/
│   ├── ddc/
│   ├── perforce/
│   └── jenkins/
└── terraform.tfstate

company-infrastructure-us-west-2/
├── networking/
├── databases/
├── applications/
│   ├── ddc/
│   ├── perforce/
│   └── jenkins/
└── terraform.tfstate
```

**Pros**: Complete regional isolation
**Cons**: Repository proliferation, monolithic state files, team conflicts

##### **Pattern B: Application-Specific with Regional Folders (Recommended)**
**Application-specific repositories with regional deployment folders:**
```
company-ddc-infrastructure/
├── deployments/
│   ├── us-east-1/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfstate
│   └── us-west-2/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfstate
└── modules/
    └── shared-components/

company-perforce-infrastructure/
├── deployments/
│   ├── us-east-1/
│   └── us-west-2/
└── modules/
```

**Pros**: Application-focused ownership, separate state files, team independence
**Cons**: Requires coordination for cross-region features

**Why Pattern B Works Better**:
- **Application ownership**: Repository aligns with team responsibilities
- **Separate state files**: Each region has independent, manageable state
- **Team independence**: Teams can work on different regions simultaneously
- **Focused scope**: Smaller, application-specific state files
- **Scalable**: Multiple deployments per region possible

#### **CGD Toolkit Multi-Region Philosophy**
**Multi-region in game development is about PERFORMANCE, not disaster recovery.**

**Why We're Different**: Game development applications (Perforce, DDC) work perfectly in single-region but are **often deployed multi-region** for geographically distributed teams.

**Primary Use Case**: **Global Development Teams**
- **DDC**: Works great single-region, but multi-region provides low-latency cache access for global teams
- **Perforce**: Perfectly functional single-region, but multi-region enables synchronized repositories across continents
- **Performance-driven**: Multi-region reduces latency for geographically distributed developers
- **Single-region viable**: Both applications work perfectly fine in single-region deployments
- **Multi-region benefit**: Global teams get better performance with regional data locality

**Primary Purpose: Performance, NOT Disaster Recovery**: 
- **Performance-driven**: Multi-region DDC/Perforce is for **active global usage** and low-latency access
- **DR as side benefit**: Cross-region replication for performance means either region *could* serve as DR
- **Nuanced DR considerations**: While data replication enables DR capabilities, full DR requires application-specific planning
- **Separate DR deployments**: For dedicated DR (not performance), use completely separate Terraform deployments

**Why We Break the Anti-Pattern Rule**:
- **Performance benefit**: Global teams get better performance with low-latency regional access
- **Cross-region coordination**: When deploying multi-region, replication setup requires shared resources
- **Single system**: Multi-region deployments create one global application, not separate deployments
- **Optional optimization**: Multi-region is a performance optimization, not a technical requirement

#### **Single Apply Requirement**
**CRITICAL**: All CGD Toolkit modules MUST support single-step multi-region deployment.

```bash
# This MUST work - single command deploys all regions
terraform apply
# ✅ Deploys us-east-1 DDC + us-west-2 DDC + cross-region replication
```

**Why Single Apply Matters**:
- **Global replication setup**: Cross-region configuration happens during initial deployment
- **Dependency coordination**: Primary region creates resources that secondary regions need
- **User experience**: Multi-region should be as easy as single-region
- **Production readiness**: No manual coordination steps between regions

#### **Terraform Multi-Region Fundamentals**
**Each Module Instance = Exactly One Region**

```hcl
# This is the fundamental pattern - each module does ONE region only
module "ddc_us_east_1" {
  source = "../../modules/unreal-cloud-ddc"
  region = "us-east-1"  # This instance ONLY handles us-east-1
}

module "ddc_us_west_2" {
  source = "../../modules/unreal-cloud-ddc"
  region = "us-west-2"  # This instance ONLY handles us-west-2
}
```

**Key Principle**: Users instantiate the module once per region they want.

**AWS Provider v6 Revolution**: Enhanced region support eliminates AWS provider aliases.

#### **Before AWS Provider v6 (Traditional)**
**Problem**: Every region needed explicit AWS provider aliases

```hcl
# Root module - OLD WAY (still needed for non-AWS providers)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

module "ddc_us_east_1" {
  source = "./modules/unreal-cloud-ddc"
  providers = {
    aws        = aws.us_east_1     # Explicit AWS alias required
    kubernetes = kubernetes.us_east_1
  }
}

module "ddc_us_west_2" {
  source = "./modules/unreal-cloud-ddc"
  providers = {
    aws        = aws.us_west_2     # Explicit AWS alias required
    kubernetes = kubernetes.us_west_2
  }
}
```

#### **With AWS Provider v6 (Enhanced Region Support)**
**Magic**: AWS provider automatically inherits region from module configuration

```hcl
# Root module - NEW WAY
# NO AWS provider aliases needed!

module "ddc_us_east_1" {
  source = "./modules/unreal-cloud-ddc"
  region = "us-east-1"  # AWS Provider v6 magic - auto-inherits region
  
  # Only non-enhanced providers need aliases
  providers = {
    kubernetes = kubernetes.us_east_1
    helm       = helm.us_east_1
  }
}

module "ddc_us_west_2" {
  source = "./modules/unreal-cloud-ddc"
  region = "us-west-2"  # AWS Provider v6 magic - auto-inherits region
  
  # Only non-enhanced providers need aliases
  providers = {
    kubernetes = kubernetes.us_west_2
    helm       = helm.us_west_2
  }
}

# Still need aliases for non-enhanced providers
provider "kubernetes" {
  alias = "us_east_1"
  host = module.ddc_us_east_1.cluster_endpoint
}

provider "kubernetes" {
  alias = "us_west_2"
  host = module.ddc_us_west_2.cluster_endpoint
}
```

#### **How AWS Provider v6 Works**
1. **Module declares region**: `region = "us-east-1"`
2. **AWS provider auto-configures**: Uses that region automatically
3. **No aliases needed**: AWS resources deploy to correct region
4. **Simple scaling**: Add regions by adding module blocks (max 2 recommended)

#### **What Still Needs Aliases**
- **Kubernetes provider**: Not enhanced, needs manual aliases
- **Helm provider**: Not enhanced, needs manual aliases
- **kubectl provider**: Not enhanced, needs manual aliases
- **Any other provider**: Only AWS has enhanced region support

#### **Inside CGD Toolkit Modules**
**How modules handle the region variable**:

```hcl
# modules/unreal-cloud-ddc/variables.tf
variable "region" {
  type        = string
  description = "AWS region for deployment"
}

# modules/unreal-cloud-ddc/main.tf
# AWS resources automatically use the region from variable
resource "aws_eks_cluster" "main" {
  name = "${local.name_prefix}-cluster-${var.region}"
  # AWS Provider v6 automatically uses var.region
}

# Pass region to submodules
module "infra" {
  source = "./modules/infra"
  region = var.region  # Propagate region down
  providers = { aws = aws }  # AWS provider inherits region automatically
}
```

**Benefits**:
- **AWS Provider v6**: Simplified region handling, no aliases needed
- **Other providers**: Still require manual aliases per region
- **Clean code**: Each module block identical except for region

#### **Multi-Region Implementation Pattern**

##### **Explicit Module Blocks (Only Recommended Pattern)**
**Best for**: Multi-region deployments (max 2 regions)

```hcl
# examples/multi-region-basic/main.tf
# Clear, explicit, easy to understand

# Primary Region - Creates shared resources
module "ddc_primary" {
  source = "../../modules/unreal-cloud-ddc"
  region = "us-east-1"
  
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }
  
  scylla_config = {
    current_region = {
      datacenter_name = "us_east"
      replication_factor = 3
      node_count = 3
    }
    enable_cross_region_replication = true
  }
  
  # Primary creates bearer token for replication
  bearer_token_replica_regions = ["us-west-2"]
}

# Secondary Region - Uses shared resources
module "ddc_secondary" {
  source = "../../modules/unreal-cloud-ddc"
  region = "us-west-2"
  
  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
  }
  
  scylla_config = {
    current_region = {
      datacenter_name = "us_west"
      replication_factor = 2
      node_count = 2
    }
    enable_cross_region_replication = true
  }
  
  # Secondary uses primary's bearer token
  create_bearer_token = false
  bearer_token_secret_arn = module.ddc_primary.bearer_token_secret_arn
  
  depends_on = [module.ddc_primary]  # Ensures proper ordering
}
```

**Benefits**:
- ✅ **Clear and explicit** - obvious what's deployed where
- ✅ **Different configurations** - each region can have unique settings
- ✅ **Easy debugging** - clear dependency chain
- ✅ **Single apply** - all regions deployed together

#### **DNS and Regional Endpoint Patterns**

##### **Private DNS Zones (Always Created)**
**All CGD Toolkit modules automatically create private DNS zones for internal service discovery:**

```hcl
# Always create private zone for internal routing
resource "aws_route53_zone" "private" {
  name = var.existing_route53_public_hosted_zone_name != null ? 
    "${var.project_prefix}.${var.existing_route53_public_hosted_zone_name}" : 
    "${var.project_prefix}.internal"
  
  vpc {
    vpc_id = var.existing_vpc_id
  }
}

# Internal service discovery records
resource "aws_route53_record" "service_internal" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "service"
  type    = "A"
  ttl     = 300
  records = [aws_lb.nlb.dns_name]
}
```

##### **Regional Endpoint Strategy**
**Following AWS service patterns, we default to regional endpoints:**

```hcl
# Regional DNS pattern (our default)
locals {
  regional_dns_name = var.existing_route53_public_hosted_zone_name != null ? 
    "${var.region}.${local.service_name}.${var.existing_route53_public_hosted_zone_name}" : 
    null
    
  service_name = "ddc"  # or "perforce", "jenkins", etc.
}

# Examples of regional endpoints:
# us-east-1.ddc.company.com
# us-west-2.ddc.company.com
# eu-west-1.perforce.company.com
```

**Why Regional Endpoints**:
- **Performance**: Direct routing to nearest region
- **Isolation**: Regional failures don't affect DNS routing
- **Explicit control**: Users know exactly which region they're accessing
- **AWS consistency**: Follows AWS service endpoint patterns

##### **Global Endpoint Flexibility**
**Users can optionally create global endpoints with routing policies:**

```hcl
# Optional: Global endpoint with latency-based routing
resource "aws_route53_record" "global_latency" {
  zone_id = var.existing_route53_public_hosted_zone_id
  name    = "ddc"  # Global endpoint: ddc.company.com
  type    = "A"
  
  set_identifier = "us-east-1"
  latency_routing_policy {
    region = "us-east-1"
  }
  
  alias {
    name    = module.ddc_primary.nlb_dns_name
    zone_id = module.ddc_primary.nlb_zone_id
  }
}

resource "aws_route53_record" "global_latency_secondary" {
  zone_id = var.existing_route53_public_hosted_zone_id
  name    = "ddc"  # Same global endpoint
  type    = "A"
  
  set_identifier = "us-west-2"
  latency_routing_policy {
    region = "us-west-2"
  }
  
  alias {
    name    = module.ddc_secondary.nlb_dns_name
    zone_id = module.ddc_secondary.nlb_zone_id
  }
}
```

**Global Routing Options**:
- **Latency-based**: Route to lowest latency region
- **Geolocation**: Route based on user's geographic location
- **Failover**: Primary/secondary with health checks
- **Weighted**: Distribute traffic by percentage

##### **DNS Output Strategy**
**Modules provide both regional and global DNS flexibility:**

```hcl
# Module outputs for DNS flexibility
output "dns_endpoints" {
  description = "DNS endpoints for service access"
  value = {
    # Regional endpoints (always available)
    regional = {
      public_dns  = local.regional_dns_name
      private_dns = "${local.service_name}.${aws_route53_zone.private.name}"
    }
    
    # Load balancer details for global routing
    load_balancer = {
      nlb_dns_name = aws_lb.nlb.dns_name
      nlb_zone_id  = aws_lb.nlb.zone_id
    }
  }
}
```

**This approach provides**:
- **Regional by default**: Each region gets its own endpoint
- **Global flexibility**: Users can create global endpoints if needed
- **Internal routing**: Private DNS for service-to-service communication
- **Load balancer access**: Direct NLB access for advanced routing scenarios

#### **Networking and Security Boundaries**

##### **Clear Demarcation: What Modules DON'T Create**
**CGD Toolkit modules have clear boundaries - we don't create foundational infrastructure:**

**🚫 Modules DO NOT Create:**
- **VPCs and Subnets**: Users provide existing VPC and subnet IDs
- **SSL/TLS Certificates**: Users provide existing ACM certificate ARNs
- **Public Hosted Zones**: Users provide existing Route53 hosted zone names
- **VPC-to-VPC Connectivity**: Peering connections, Transit Gateway, etc.
- **Network ACLs**: Users manage network-level security
- **Internet/NAT Gateways**: Users provide connectivity infrastructure

**✅ Modules DO Create:**
- **Private DNS zones**: For internal service discovery
- **Security groups**: For service-specific access control
- **Load balancers**: NLB/ALB for service access
- **DNS records**: In both private and public zones (when provided)

##### **SSL/TLS Certificate Integration**
**Modules integrate with existing certificates, don't create them:**

```hcl
# User creates certificate outside module
resource "aws_acm_certificate" "service_cert" {
  domain_name       = "*.ddc.company.com"
  validation_method = "DNS"
  
  subject_alternative_names = [
    "ddc.company.com",
    "*.us-east-1.ddc.company.com",
    "*.us-west-2.ddc.company.com"
  ]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Module accepts certificate reference
module "ddc" {
  source = "../../modules/unreal-cloud-ddc"
  
  # Pass existing certificate ARN
  existing_certificate_arn = aws_acm_certificate.service_cert.arn
  
  # Module configures HTTPS listeners
  # Module handles certificate attachment to load balancers
}
```

**Why This Approach**:
- **Certificate lifecycle**: Users control certificate renewal and management
- **Domain ownership**: Users own and validate their domains
- **Security control**: Certificate management stays with domain owners
- **Flexibility**: Users can use existing certificate management processes

##### **VPC and Subnet Integration**
**Modules work within existing network infrastructure:**

```hcl
# User provides existing network infrastructure
module "ddc" {
  source = "../../modules/unreal-cloud-ddc"
  
  # Existing VPC (user-created)
  existing_vpc_id = "vpc-12345678"
  
  # Existing subnets (user-created)
  existing_load_balancer_subnets = [
    "subnet-12345678",  # Public subnet for internet-facing LB
    "subnet-87654321"   # Public subnet for HA
  ]
  
  existing_service_subnets = [
    "subnet-abcdef12",  # Private subnet for EKS/services
    "subnet-21fedcba"   # Private subnet for HA
  ]
  
  # Module creates resources within provided network
}
```

**Network Architecture Assumptions**:
- **Public subnets**: For internet-facing load balancers
- **Private subnets**: For EKS clusters, databases, internal services
- **NAT Gateway**: Users provide internet access for private subnets
- **Route tables**: Users configure routing for subnets
- **VPC endpoints**: Users create for AWS service access (optional)

##### **Security Group Strategy**
**Modules create service-specific security groups, users control external access:**

```hcl
# Users create external access security groups
resource "aws_security_group" "office_access" {
  name_prefix = "office-access-"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "office_https" {
  security_group_id = aws_security_group.office_access.id
  description       = "HTTPS from office network"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "203.0.113.0/24"  # Office CIDR
}

# Module accepts user-controlled security groups
module "ddc" {
  source = "../../modules/unreal-cloud-ddc"
  
  # User-controlled external access
  existing_security_groups = [
    aws_security_group.office_access.id
  ]
  
  # Module creates internal security groups for service communication
}
```

**Security Responsibilities**:
- **Users control**: External access rules, CIDR blocks, source security groups
- **Modules create**: Internal service communication rules, AWS API access
- **Principle**: Users define "who can access", modules define "how services communicate"

##### **Public Hosted Zone Integration**
**Modules use existing public zones, don't create them:**

```hcl
# User owns and manages public hosted zone
data "aws_route53_zone" "company" {
  name = "company.com"
}

# Module uses existing zone for public DNS records
module "ddc" {
  source = "../../modules/unreal-cloud-ddc"
  
  # Reference existing public zone
  existing_route53_public_hosted_zone_name = "company.com"
  
  # Module creates records like: us-east-1.ddc.company.com
  # Module does NOT create the company.com zone
}
```

**DNS Responsibilities**:
- **Users own**: Domain registration, public hosted zone management
- **Modules create**: Service-specific DNS records in provided zones
- **Private zones**: Modules always create for internal service discovery

##### **Multi-Region Network Considerations**
**For multi-region deployments, users handle cross-region connectivity:**

```hcl
# Users create VPC peering or Transit Gateway (outside modules)
resource "aws_vpc_peering_connection" "cross_region" {
  vpc_id      = var.primary_vpc_id    # us-east-1
  peer_vpc_id = var.secondary_vpc_id  # us-west-2
  peer_region = "us-west-2"
  
  # Users manage cross-region network connectivity
}

# Modules work within each region's VPC independently
module "ddc_primary" {
  existing_vpc_id = var.primary_vpc_id    # us-east-1 VPC
}

module "ddc_secondary" {
  existing_vpc_id = var.secondary_vpc_id  # us-west-2 VPC
}
```

**Cross-Region Network Responsibilities**:
- **Users handle**: VPC peering, Transit Gateway, cross-region routing
- **Modules handle**: Application-level cross-region communication (database replication, etc.)
- **Clear separation**: Network connectivity vs. application connectivity

##### **Example Integration Pattern**
**Complete example showing user vs. module responsibilities:**

```hcl
# USER RESPONSIBILITIES (outside module)
# 1. VPC and networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# 2. SSL certificate
resource "aws_acm_certificate" "ddc" {
  domain_name = "*.ddc.company.com"
}

# 3. External access security group
resource "aws_security_group" "external_access" {
  vpc_id = aws_vpc.main.id
}

# MODULE RESPONSIBILITIES (inside module)
module "ddc" {
  source = "../../modules/unreal-cloud-ddc"
  
  # Use existing infrastructure
  existing_vpc_id                          = aws_vpc.main.id
  existing_certificate_arn                 = aws_acm_certificate.ddc.arn
  existing_security_groups                 = [aws_security_group.external_access.id]
  existing_route53_public_hosted_zone_name = "company.com"
  
  # Module creates: EKS, NLB, private DNS, internal security groups
}
```

**This pattern ensures**:
- **Clear ownership**: Users own foundational infrastructure
- **Module focus**: Modules focus on service-specific resources
- **Flexibility**: Users can integrate with existing infrastructure
- **Security**: Users control access boundaries, modules handle service communication



#### **Multi-Region Design Requirements for All Modules**

##### **MUST Support Single Apply (For Inherently Multi-Region Apps)**
**CGD Toolkit modules that are inherently multi-region MUST enable single-step deployment:**

```bash
# This MUST work for Perforce, DDC, and similar cross-region apps
cd examples/multi-region-basic/
terraform init
terraform apply  # Deploys PRIMARY + SECONDARY regions (MAX 2)
```

**⚠️ IMPORTANT**: This is ONLY for applications that require cross-region replication by design.

##### **Cross-Region Coordination Patterns**
**Primary/Secondary Pattern** (Recommended):
- **Primary region**: Creates shared resources (bearer tokens, seed nodes)
- **Secondary regions**: Reference primary's outputs
- **Dependencies**: `depends_on = [module.primary]` ensures proper ordering

##### **Module Implementation Standards**
**For inherently multi-region modules (Perforce, DDC):**

- **Single apply**: PRIMARY + SECONDARY regions (MAX 2) deploy with one `terraform apply`
- **Cross-region variables**: Support peer region configuration
- **Dependency management**: Use `depends_on` for proper ordering
- **Regional DNS**: Support regional endpoints (us-east-1.service.domain.com)
- **Shared resources**: Primary creates, secondary references
- **Provider compatibility**: Work with AWS Provider v6 enhanced regions
- **Example provided**: Working multi-region example in `examples/`
- **Documentation**: Clear guidance on when to use separate deployments instead

##### **⚠️ CRITICAL: When NOT to Use Multi-Region Single State**

**🚫 ABSOLUTE ANTI-PATTERNS:**
- **General applications**: Most apps should be single-region
- **Dedicated disaster recovery**: Use completely separate Terraform deployments for DR-only scenarios
- **Environment separation**: dev/staging/prod should be separate states
- **"Just in case" deployments**: Don't deploy to regions you don't actively use
- **More than 2 regions in one state**: Creates unmanageable complexity

**✅ ONLY Valid Use Cases:**
- **Applications that benefit from multi-region**: Perforce, DDC where cross-region replication improves performance
- **Active global usage**: All regions actively used by distributed teams for better performance
- **Performance optimization**: Low-latency access across continents for same application data
- **Maximum 1-2 regions**: Keep state files manageable
- **Single-region alternative**: Remember these applications work perfectly fine single-region too

**🎯 The Rule**: If your application doesn't REQUIRE cross-region data replication for **performance/functionality**, use separate Terraform deployments per region.

**DR Considerations**:
- **Side benefit**: Performance-driven replication means either region could serve as DR
- **Application-specific**: Each application (DDC, Perforce) has different DR capabilities and requirements
- **Not primary purpose**: DR should not be the main reason for choosing multi-region single-state pattern
- **Dedicated DR**: For DR-only scenarios, use separate Terraform deployments in different regions

#### **Summary: Multi-Region Best Practices**

**Recommended Approach**: Use explicit module blocks - MAX 2 regions
```hcl
module "service_primary" { region = "us-east-1" }
module "service_secondary" { region = "us-west-2" }
# ❌ DON'T ADD MORE - Use separate Terraform deployments instead
```

**🎯 For Most Applications**: Deploy each region as separate Terraform root modules
```bash
# Recommended pattern for most applications (follows Pattern B above)
cd deployments/us-east-1/
terraform apply  # Separate state file

cd ../us-west-2/
terraform apply  # Separate state file
```

**This follows Pattern B (Application-Specific with Regional Folders) and provides:**
- **Independent state files**: Each region manageable separately
- **Team parallelism**: Multiple teams can work simultaneously
- **Reduced blast radius**: Regional isolation prevents cascading failures
- **Application focus**: Repository ownership aligns with team responsibilities
- **Standard tooling**: Works with existing Terraform workflows

**Key Principles**:
- ✅ **Each module instance = exactly one region**
- ⚠️ **Single apply ONLY for inherently multi-region apps** (Perforce, DDC)
- ✅ **Multi-region is for performance, not DR**
- ⚠️ **Maximum 1-2 regions per state file**
- ✅ **Most applications should use separate Terraform deployments per region**
- ✅ **Use explicit module blocks, not dynamic generation**
- ✅ **AWS Provider v6 eliminates AWS provider aliases**

**Benefits**:
- **Performance**: Low latency for global teams
- **Single deployment**: All regions with one `terraform apply`
- **Global replication**: Cross-region data sharing
- **AWS Provider v6**: Simplified region handling

**⚠️ CRITICAL Considerations**:
- **🔥 State file explosion**: More regions = exponentially larger, slower state
- **🔥 Massive blast radius**: One mistake destroys all regions
- **🔥 Performance degradation**: `terraform plan` becomes painfully slow
- **🔥 Team paralysis**: Multiple teams can't work independently
- **🔥 Debugging nightmare**: Finding issues across regions becomes impossible
- **Network costs**: Cross-region data transfer charges
- **Complexity**: Exponentially more moving parts to troubleshoot

**🎯 Solution**: Use separate Terraform deployments for most applications

### **Version Conflicts and Resolution**
**Common Problem**: Different modules require different provider versions

#### **Conflict Scenario**
```hcl
# Module A requires
kubernetes = { version = ">= 2.30.0" }

# Module B requires  
kubernetes = { version = ">= 2.33.0, < 2.35.0" }

# Root module must satisfy BOTH
kubernetes = { version = ">= 2.33.0, < 2.35.0" }  # Intersection
```

#### **Resolution Strategy**
1. **Use intersection of all constraints**: Find version range that satisfies all modules
2. **Update modules**: Align version requirements across CGD Toolkit
3. **Test compatibility**: Ensure chosen version works with all modules
4. **Document decisions**: Explain version choices in examples

#### **Multi-Region Version Management**
```hcl
# Root module must declare ALL provider versions for ALL regions
terraform {
  required_providers {
    aws = { version = ">= 6.0.0" }  # Enhanced region support
    kubernetes = { version = ">= 2.33.0" }  # All regions use same version
    helm = { version = ">= 2.16.0, < 3.0.0" }
  }
}

# Each region gets same provider versions
provider "kubernetes" {
  alias = "us_east_1"
  # Same version as declared above
}

provider "kubernetes" {
  alias = "us_west_2" 
  # Same version as declared above
}
```

### **Provider Configuration Timing**
**Critical**: Understanding WHEN provider configurations are evaluated

```bash
# Terraform command lifecycle:
# 1. terraform init - Downloads providers, NO configuration evaluation
# 2. terraform plan - Provider configurations evaluated HERE
# 3. terraform apply - Configurations re-evaluated if dependencies changed
```

**Implications**:
- **First run**: Infrastructure doesn't exist, providers get null values
- **Second run**: Infrastructure exists, providers get real values
- **Dependencies**: Provider configs must handle missing dependencies gracefully

## AWS Provider Best Practices

### **Security Group Rules**
```hcl
# ✅ Use dedicated rule resources (AWS Provider v6 requirement)
resource "aws_vpc_security_group_ingress_rule" "example" {
  security_group_id = aws_security_group.example.id
  description       = "HTTP access from office network"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "203.0.113.0/24"
}

# ❌ Don't use inline rules or aws_security_group_rule
resource "aws_security_group" "bad" {
  ingress { /* ... */ }  # Deprecated pattern
}
```

### **IAM Policies**
```hcl
# ✅ Use policy documents
data "aws_iam_policy_document" "example" {
  statement {
    effect = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.example.arn}/*"]
  }
}

resource "aws_iam_policy" "example" {
  name   = "example-policy"
  policy = data.aws_iam_policy_document.example.json
}

# ❌ Avoid jsonencode unless absolutely necessary
resource "aws_iam_policy" "bad" {
  policy = jsonencode({ /* ... */ })
}
```

### **IAM Role Attachments**
```hcl
# ✅ Use attachment resources
resource "aws_iam_role" "example" {
  name = "example-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ❌ Don't use deprecated arguments
resource "aws_iam_role" "bad" {
  managed_policy_arns = ["..."]  # Deprecated
  inline_policy { /* ... */ }    # Deprecated
}
```

## Output Strategy

### **What to Include**
**Philosophy**: Expose what users commonly need, expand based on requests.

```hcl
# Connection information
output "service_endpoints" {
  description = "Service connection endpoints"
  value = {
    nlb_dns   = aws_lb.nlb.dns_name
    https_url = local.public_dns_name != null ? "https://${local.public_dns_name}" : null
  }
}

# Integration points
output "cluster_info" {
  description = "EKS cluster information for kubectl"
  value = {
    cluster_name     = aws_eks_cluster.main.name
    cluster_endpoint = aws_eks_cluster.main.endpoint
    cluster_ca_data  = aws_eks_cluster.main.certificate_authority[0].data
  }
}

# Automation helpers
output "security_group_ids" {
  description = "Security group IDs for additional rules"
  value = {
    nlb      = aws_security_group.nlb.id
    internal = aws_security_group.internal.id
  }
}
```

**Include**: Connection info, integration points, automation helpers  
**Exclude**: Internal implementation details, rarely used attributes  
**Request Pattern**: Users can request additional outputs via PR

## Breaking Changes Prevention

### **Critical Rules**
- **NEVER change logical names** without `moved` blocks
- **NEVER change variable names** in minor/patch versions
- **ALWAYS use major version bumps** for breaking changes
- **ALWAYS test migration paths** with real state files

### **Safe Patterns**
```hcl
# ✅ SAFE - Adding resources, optional variables with defaults, new outputs
resource "aws_s3_bucket" "new_feature" { }

variable "new_option" {
  type    = bool
  default = false  # Required default
}

output "new_info" {
  value = aws_s3_bucket.new_feature.id
}
```

## Implementation Checklist

### **For New Modules**
- [ ] Use 3-tier architecture variables
- [ ] Implement standardized logical names
- [ ] Use random IDs for predictable naming
- [ ] Create private DNS zones automatically
- [ ] Implement security group strategy (no 0.0.0.0/0 ingress)
- [ ] Add comprehensive examples with versions.tf
- [ ] Create tests with setup/ directory
- [ ] Document architecture and usage patterns

### **For Existing Modules**
- [ ] Plan breaking changes for major versions only
- [ ] Add `moved` blocks for renamed resources
- [ ] Update variable naming to match standards
- [ ] Test upgrade paths with real state files
- [ ] Create migration documentation

---

## Building Great Modules Together

These standards represent our collective wisdom from building production game development infrastructure. By following these patterns, you're contributing to a toolkit that:

- **Empowers game developers** to focus on creating amazing games instead of wrestling with infrastructure
- **Reduces cognitive load** through consistent, predictable interfaces
- **Scales with teams** from indie studios to AAA publishers
- **Evolves safely** with backward compatibility and clear migration paths

Every module you build following these standards makes the entire ecosystem stronger. Thank you for being part of this journey!

**Questions or Ideas?** Open an issue or discussion - we love hearing from the community and these standards improve through your feedback.