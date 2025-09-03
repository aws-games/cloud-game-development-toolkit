# CGD Toolkit Module Standards

## Overview

This document defines the gold standards for all Cloud Game Development Toolkit modules. These standards ensure consistency, maintainability, and scalability across the entire toolkit.

## Core Design Principles

### **1. Readability First**
- No complex abstractions that obscure functionality
- Simple, clear variable names and structure
- Self-documenting code over clever implementations

### **2. Flexibility Through Modularity**
- Modules are building blocks, not opinionated solutions
- Configuration decisions belong in examples, not modules
- Support multiple architecture patterns through simple variables

### **3. Conservative Variable Exposure**
- Expose variables only when we KNOW users will change them
- Easier to add variables later than remove them (breaking changes)
- Start minimal, expand based on feature requests

### **4. Security by Default**
- No 0.0.0.0/0 ingress rules in module code
- Outbound 0.0.0.0/0 egress rules acceptable for AWS APIs and updates
- HTTPS-first for internet-facing services
- Private subnets for all compute resources

## Variable Naming Standards

### **External Resource References**
```hcl
# ✅ CORRECT - Use existing_ prefix for user-provided resources
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

# ❌ INCORRECT - Topology-based naming
variable "public_subnets" { }
variable "private_subnets" { }
```

### **Module Configuration**
```hcl
# ✅ CORRECT - Purpose-based, configurable
variable "project_prefix" {
  type        = string
  description = "Prefix for all resource names"
  default     = "cgd"
}

variable "kubernetes_version" {
  type        = string
  description = "EKS cluster Kubernetes version"
  default     = "1.33"
}

variable "debug_mode" {
  type        = string
  description = "Debug mode: 'enabled' allows HTTP, 'disabled' enforces HTTPS"
  default     = "disabled"
  
  validation {
    condition     = contains(["enabled", "disabled"], var.debug_mode)
    error_message = "debug_mode must be 'enabled' or 'disabled'"
  }
}
```

### **Security Group Strategy**
```hcl
# Tiered security group access
variable "existing_security_groups" {
  type        = list(string)
  description = "Security group IDs for general access to public services"
  default     = []
}

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

## Resource Naming Standards

### **Use Random IDs for Predictable Names**
```hcl
# ✅ CORRECT - Predictable, conflict-free naming
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

# ❌ INCORRECT - Unpredictable name_prefix
resource "aws_lb" "nlb" {
  name_prefix = "cgd-ddc-"  # AWS generates random suffix
}
```

### **Standardized Logical Names**
```hcl
# ✅ CORRECT - Consistent across all modules
resource "aws_lb" "nlb" { }                    # Network Load Balancer
resource "aws_lb" "alb" { }                    # Application Load Balancer
resource "aws_eks_cluster" "main" { }          # Primary EKS cluster
resource "aws_security_group" "nlb" { }        # NLB security group
resource "aws_security_group" "eks_cluster" { } # EKS cluster security group
resource "aws_security_group" "internal" { }   # Internal service communication
resource "aws_s3_bucket" "artifacts" { }       # Artifacts storage
resource "aws_s3_bucket" "logs" { }            # Logs storage
resource "aws_route53_zone" "private" { }      # Private DNS zone

# ❌ INCORRECT - Inconsistent naming
resource "aws_lb" "this" { }           # Too generic
resource "aws_lb" "ddc_nlb" { }        # Module-specific
resource "aws_lb" "load_balancer" { }  # Verbose
```

## Module Architecture Standards

### **File Structure Standards**
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

### **Parent Module Structure**
```hcl
########################################
# Required Infrastructure (Users Provide)
########################################
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

########################################
# Module Configuration (We Create)
########################################
variable "project_prefix" {
  type        = string
  description = "Prefix for all resource names"
  default     = "cgd"
}

variable "region" {
  type        = string
  description = "AWS region for deployment"
}

########################################
# Submodule Collections (Complex Config)
########################################
variable "infra_config" {
  type = object({
    kubernetes_version = optional(string, "1.33")
    node_instance_type = optional(string, "m5.large")
    enable_monitoring  = optional(bool, true)
  })
  description = "Infrastructure configuration"
  default     = {}
}
```

### **When to Use Submodules**
```hcl
# ✅ GOOD - Different providers required
module "infra" {
  source = "./modules/infra"
  providers = { aws = aws }
}

module "services" {
  source = "./modules/services"
  providers = { 
    kubernetes = kubernetes
    helm = helm
  }
  depends_on = [module.infra]
}

# ❌ AVOID - Same provider, no clear separation
module "s3_bucket" {
  source = "./modules/s3"
  # Just create directly in parent
}
```

## DNS Standards

### **Always Create Private Zones**
```hcl
# Always create private zone (not configurable)
resource "aws_route53_zone" "private" {
  name = var.existing_route53_public_hosted_zone_name != null ? 
    "${var.project_prefix}.${var.existing_route53_public_hosted_zone_name}" : 
    "${var.project_prefix}.internal"
  
  vpc {
    vpc_id = var.existing_vpc_id
  }
}

# Always create service records
resource "aws_route53_record" "scylla" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "scylla"
  type    = "A"
  ttl     = 300
  records = aws_instance.scylla[*].private_ip
}
```

### **Regional Endpoint Pattern**
```hcl
# Multi-region DNS standard
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

## Load Balancer Standards

### **Always Create NLB**
```hcl
# Network Load Balancer (always created)
resource "aws_lb" "nlb" {
  name               = local.nlb_name
  load_balancer_type = "network"
  scheme            = var.internet_facing ? "internet-facing" : "internal"
  subnets           = var.existing_load_balancer_subnets
}

# Application Load Balancer (optional)
variable "enable_application_load_balancer" {
  type        = bool
  description = "Create ALB for HTTP/HTTPS routing (optional)"
  default     = false
}

resource "aws_lb" "alb" {
  count              = var.enable_application_load_balancer ? 1 : 0
  name               = local.alb_name
  load_balancer_type = "application"
  scheme            = var.internet_facing ? "internet-facing" : "internal"
  subnets           = var.existing_load_balancer_subnets
  security_groups   = concat(
    var.existing_security_groups,
    var.existing_load_balancer_security_groups,
    [aws_security_group.internal.id]
  )
}
```

## HTTPS/Security Standards

### **HTTPS-First Policy**
```hcl
variable "existing_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listeners (required for internet-facing)"
  default     = null
  
  validation {
    condition = var.internet_facing == false || var.existing_certificate_arn != null || var.debug_mode == "enabled"
    error_message = "Certificate ARN required for internet-facing services unless debug_mode enabled"
  }
}

# HTTPS listener (production)
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

# HTTP listener (redirect to HTTPS or debug mode)
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

## Security Standards

### **Security Group Strategy**
```hcl
# Users control external access
variable "existing_security_groups" {
  type        = list(string)
  description = "Security group IDs for external access"
  default     = []
}

# We create internal communication
resource "aws_security_group" "internal" {
  name        = "${local.name_prefix}-internal"
  description = "Internal service communication"
  vpc_id      = var.existing_vpc_id
  
  # Internal service rules only
  ingress {
    from_port = 9042
    to_port   = 9042
    protocol  = "tcp"
    self      = true
  }
}

# Apply security groups with concat
resource "aws_eks_node_group" "main" {
  security_groups = concat(
    var.existing_security_groups,              # User-controlled
    var.existing_load_balancer_security_groups, # Component-specific
    [aws_security_group.internal.id]          # Internal communication
  )
}
```

### **Validation Standards**
```hcl
# Prevent insecure configurations
variable "allowed_external_cidrs" {
  type        = list(string)
  description = "CIDR blocks for external access"
  default     = []
  
  validation {
    condition     = !contains(var.allowed_external_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed. Specify actual CIDR blocks."
  }
}
```

## Output Standards

### **Minimal, Essential Outputs**
```hcl
# Essential outputs only
output "nlb_dns_name" {
  description = "NLB DNS name for service access"
  value       = aws_lb.nlb.dns_name
}

output "service_endpoints" {
  description = "Service connection endpoints"
  value = {
    https_url = var.existing_certificate_arn != null ? 
      "https://${local.public_dns_name}" : null
    http_url = var.debug_mode == "enabled" ? 
      "http://${local.public_dns_name}" : null
    
    # Security warnings
    security_warning = var.debug_mode == "enabled" ? 
      "⚠️ DEBUG MODE - HTTP allowed. Disable for production!" : null
  }
}

# Flexible service discovery
output "database_endpoints" {
  description = "Database connection options"
  value = {
    dns_name     = "database.${aws_route53_zone.private.name}"
    ip_addresses = aws_instance.database[*].private_ip
  }
}
```

## Breaking Changes Prevention

### **Critical Rules**
- **Never change logical names** without `moved` blocks
- **Never change variable names** in minor/patch versions
- **Always use major version bumps** for breaking changes
- **Test migration paths** with real state files
- **Document all breaking changes** comprehensively

### **Safe Change Patterns**
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

## Provider Version Standards

### **AWS Provider v6.0.0 Minimum**
```hcl
terraform {
  required_version = ">= 1.11"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"  # REQUIRED minimum for enhanced region support
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

### **No Provider Configurations in Modules**
Modules should NOT define provider configurations - only version requirements.

## Testing Standards

### **REQUIRED: Terraform Test Framework**
- All modules MUST have tests using Terraform Test Framework
- All tests MUST pass for PR approval
- Use setup/ directory for SSM parameter retrieval from CI account
- Include both unit tests (plan only) and integration tests (apply)

### **Test Structure**
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

## Dependency Inversion Principle

### **Support Existing Resources**
```hcl
# ✅ GOOD - Allow users to provide existing resources
variable "existing_cluster_name" {
  type        = string
  description = "Existing ECS cluster name (if provided, skips cluster creation)"
  default     = null
}

resource "aws_ecs_cluster" "main" {
  count = var.existing_cluster_name == null ? 1 : 0
  name  = local.cluster_name
}

locals {
  cluster_name = var.existing_cluster_name != null ? 
    var.existing_cluster_name : 
    aws_ecs_cluster.main[0].name
}
```

### **Flexible Resource Creation**
- Support both "create new" and "use existing" patterns
- Allow significant dependency injection through variables
- Make modules work with diverse infrastructure setups

## Implementation Checklist

### **For New Modules**
- [ ] Use `existing_` prefix for external resources
- [ ] Implement standardized logical names
- [ ] Create private DNS zones automatically
- [ ] Use random IDs for resource naming
- [ ] Implement HTTPS-first policy
- [ ] Use tiered security group strategy
- [ ] Set conservative defaults
- [ ] Create comprehensive examples
- [ ] Add Terraform tests
- [ ] Document architecture patterns

### **For Existing Modules**
- [ ] Plan breaking changes for v2.0.0
- [ ] Add `moved` blocks for renamed resources
- [ ] Update variable naming conventions
- [ ] Implement DNS standards
- [ ] Add HTTPS enforcement
- [ ] Update security group patterns
- [ ] Create migration documentation
- [ ] Test upgrade paths

## Benefits

- **Consistency** - Same patterns across all modules
- **Maintainability** - Clear, readable code structure
- **Security** - Secure by default configurations
- **Flexibility** - Support multiple architecture patterns
- **Scalability** - Easy to extend and modify
- **Reliability** - Prevent breaking changes and state issues