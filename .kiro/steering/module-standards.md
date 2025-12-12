# Module Design Standards

## Naming Conventions

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

## Variable Structure

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

## Resource Patterns

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

**When remote modules are needed, fork them first** for full control.

## Common Patterns

### Networking - 3-Tier Architecture
- `application_subnets` - Primary business applications
- `service_subnets` - Supporting services (databases, caches)
- `load_balancer_config` - Load balancer configuration

### Load Balancer Strategy
- Default to NLB for most services
- ALB when needed for HTTP/HTTPS routing
- User controls creation via boolean flags

### DNS Patterns
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

## Documentation Requirements

Each module must include:
1. **README.md** - Module overview, usage examples, input/output documentation
2. **examples/** - Working example configurations
3. **tests/** - Terraform test files with mocked providers

## Reference

See `modules/DESIGN_STANDARDS.md` for comprehensive design standards.
