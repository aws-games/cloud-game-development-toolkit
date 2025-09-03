# CGD Toolkit Module Standards

## Overview

This rule defines the ABSOLUTE GOLD STANDARDS for all Cloud Game Development Toolkit modules. These standards ensure consistency, maintainability, and scalability across the entire toolkit.

**CRITICAL**: This rule takes ultimate preference over all other design rules. When conflicts arise, follow these standards.

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

### **ALWAYS Use `existing_` Prefix for External Resources**
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

### **Purpose-Based Variable Names**
```hcl
# ✅ CORRECT - Purpose-based, configurable
variable "project_prefix" {
  type        = string
  description = "Prefix for all resource names"
  default     = "cgd"
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

# ❌ INCORRECT - Opinionated variables
variable "access_method" { }  # Remove - let examples show patterns
```

### **Tiered Security Group Strategy**
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

## Resource Naming Standards

### **ALWAYS Use Random IDs for Predictable Names**
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

### **Standardized Logical Names Across ALL Modules**
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

### **Parent Module = Simple Orchestrator**
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
# Submodule Collections (Complex Config Only)
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

### **ALWAYS Create Private Zones (Not Configurable)**
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

# Always create service records for internal discovery
resource "aws_route53_record" "scylla" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "scylla"
  type    = "A"
  ttl     = 300
  records = aws_instance.scylla[*].private_ip
}
```

### **Regional Endpoint Pattern for Multi-Region**
```hcl
# Multi-region DNS standard: {region}.{service}.{domain}
locals {
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

### **ALWAYS Create NLB, Optional ALB**
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

### **HTTPS-First Policy with Debug Exception**
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
# Users control external access - we NEVER use 0.0.0.0/0 for ingress
variable "existing_security_groups" {
  type        = list(string)
  description = "Security group IDs for external access"
  default     = []
}

# We create internal communication with egress 0.0.0.0/0 (acceptable)
resource "aws_security_group" "internal" {
  name        = "${local.name_prefix}-internal"
  description = "Internal service communication"
  vpc_id      = var.existing_vpc_id
  
  # Internal service rules only
  ingress {
    description = "ScyllaDB CQL port"
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    self        = true  # Only from same security group
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

# Apply security groups with concat
resource "aws_eks_node_group" "main" {
  security_groups = concat(
    var.existing_security_groups,              # User-controlled
    var.existing_load_balancer_security_groups, # Component-specific
    [aws_security_group.internal.id]          # Internal communication
  )
}
```

### **REQUIRED Security Validation**
```hcl
# Prevent insecure configurations
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

## AWS Provider Standards

### **REQUIRED: Use Dedicated Security Group Rule Resources**
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
```

### **REQUIRED: Use IAM Policy Documents**
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

## Output Standards

### **Minimal, Essential Outputs Only**
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

# Flexible service discovery (both DNS and IPs)
output "database_endpoints" {
  description = "Database connection options"
  value = {
    dns_name     = "database.${aws_route53_zone.private.name}"
    ip_addresses = aws_instance.database[*].private_ip
  }
}
```

## Breaking Changes Prevention

### **CRITICAL Rules**
- **NEVER change logical names** without `moved` blocks
- **NEVER change variable names** in minor/patch versions
- **ALWAYS use major version bumps** for breaking changes
- **ALWAYS test migration paths** with real state files
- **ALWAYS document breaking changes** comprehensively

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

## Implementation Checklist

### **For ALL New Modules**
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
- [ ] Remove `access_method` variable - use examples instead

### **For Existing Modules (Breaking Changes)**
- [ ] Plan breaking changes for v2.0.0
- [ ] Add `moved` blocks for renamed resources
- [ ] Update variable naming conventions
- [ ] Implement DNS standards
- [ ] Add HTTPS enforcement
- [ ] Update security group patterns
- [ ] Create migration documentation
- [ ] Test upgrade paths

## Key Reminders

### **When Working on ANY Module**
- **Think twice**: Is this change really necessary?
- **Conservative exposure**: Only expose variables users WILL change
- **Security first**: No 0.0.0.0/0 ingress rules, ever
- **Consistency**: Use standardized logical names across all modules
- **Documentation**: Update examples and README for any changes
- **Testing**: Always test with real state files

### **When Reviewing Module Code**
- **Block PRs**: Don't approve breaking changes without proper migration
- **Check naming**: Ensure `existing_` prefix and standardized logical names
- **Verify security**: No 0.0.0.0/0 ingress rules in module code
- **Validate patterns**: Consistent with these gold standards

This rule represents the ABSOLUTE GOLD STANDARD for all CGD Toolkit modules. When in doubt, follow these patterns exactly.