# DDC Module VPC Endpoints Implementation - Steering Document

## Current State Analysis
**Module**: `modules/unreal/unreal-cloud-ddc/`
**Analysis Date**: 2024-12-19
**Status**: 🎯 PLANNING PHASE

## Executive Summary
Implement VPC endpoints support to eliminate complex EKS proxy NLB infrastructure, reduce costs, improve security, and provide truly private AWS API access. This will vastly simplify the current 3-mode EKS access pattern while maintaining backward compatibility.

## 🎯 CRITICAL SUCCESS FACTORS
1. **ELIMINATE PROXY COMPLEXITY** - Remove proxy NLB, DNS zones, security group complexity
2. **MAINTAIN BACKWARD COMPATIBILITY** - Existing configurations continue to work
3. **FLEXIBLE ENDPOINT MANAGEMENT** - Per-service control, existing endpoint support
4. **COST REDUCTION** - VPC endpoints (~$7/month) cheaper than proxy NLB (~$16/month)
5. **SECURITY IMPROVEMENT** - No internet egress required for AWS API calls

---

## Phase 1: VPC Endpoints Variable Design 🚀
**Status**: 🔄 PLANNING
**Objective**: Design flexible VPC endpoints configuration structure
**Priority**: CRITICAL - Foundation for all implementation

### 🎯 IMPLEMENTATION TASKS:

#### **1.1** - Design VPC Endpoints Variable Structure
```hcl
variable "vpc_endpoints" {
  type = object({
    # EKS API endpoint (primary focus)
    eks = optional(object({
      enabled              = optional(bool, false)
      existing_endpoint_id = optional(string, null)  # Reference existing
      subnet_ids           = optional(list(string), []) # Uses EKS subnets if empty
      security_group_ids   = optional(list(string), []) # Uses internal SG if empty
      policy_document      = optional(string, null)   # Custom endpoint policy
    }), null)
    
    # Future endpoints (Phase 2)
    ecr_api = optional(object({
      enabled              = optional(bool, false)
      existing_endpoint_id = optional(string, null)
      subnet_ids           = optional(list(string), [])
      security_group_ids   = optional(list(string), [])
    }), null)
    
    ecr_dkr = optional(object({
      enabled              = optional(bool, false)
      existing_endpoint_id = optional(string, null)
      subnet_ids           = optional(list(string), [])
      security_group_ids   = optional(list(string), [])
    }), null)
    
    s3 = optional(object({
      enabled              = optional(bool, false)
      existing_endpoint_id = optional(string, null)
      route_table_ids      = optional(list(string), []) # Gateway endpoint
    }), null)
  })
  
  description = <<-EOT
    VPC endpoints configuration for private AWS API access.
    
    When enabled, eliminates need for internet egress and proxy infrastructure.
    Each service can be enabled individually or reference existing endpoints.
    
    Example:
    vpc_endpoints = {
      eks = {
        enabled = true  # Creates EKS VPC endpoint, eliminates proxy NLB
      }
    }
  EOT
  
  default = null
}
```

#### **1.2** - Add Validation Logic
```hcl
validation {
  condition = var.vpc_endpoints == null ? true : alltrue([
    # Can't have both enabled and existing_endpoint_id
    var.vpc_endpoints.eks == null ? true : !(
      var.vpc_endpoints.eks.enabled == true && 
      var.vpc_endpoints.eks.existing_endpoint_id != null
    )
  ])
  error_message = "Cannot specify both enabled=true and existing_endpoint_id for the same VPC endpoint."
}
```

#### **1.3** - Update EKS Access Config (Simplified)
```hcl
# Simplify existing eks_access_config - remove proxy complexity
variable "ddc_infra_config" {
  type = object({
    eks_access_config = optional(object({
      mode = optional(string, "hybrid")  # private, public, hybrid
      
      public = optional(object({
        enabled       = optional(bool, true)
        allowed_cidrs = list(string)
      }), null)
      
      # SIMPLIFIED - no more proxy NLB config when VPC endpoint used
      private = optional(object({
        enabled = optional(bool, true)
        # Remove: create_proxy_nlb, proxy_port, proxy_dns_name, security_groups
        # VPC endpoint handles private access automatically
      }), null)
    }), {
      mode = "hybrid"
    })
  })
}
```

---

## Phase 2: VPC Endpoint Resources Implementation 🎯
**Status**: ⏳ PENDING - WAITING FOR PHASE 1
**Objective**: Create VPC endpoint resources with conditional logic

### Tasks:

#### **2.1** - Create VPC Endpoints File
```hcl
# vpc-endpoints.tf
################################################################################
# VPC Endpoints for Private AWS API Access
################################################################################

locals {
  # Determine if EKS uses VPC endpoint (enabled or existing)
  eks_uses_vpc_endpoint = var.vpc_endpoints != null && var.vpc_endpoints.eks != null && (
    var.vpc_endpoints.eks.enabled == true || 
    var.vpc_endpoints.eks.existing_endpoint_id != null
  )
  
  # Default subnets and security groups for endpoints
  default_endpoint_subnets = var.ddc_infra_config.eks_node_group_subnets
  default_endpoint_security_groups = [aws_security_group.internal[0].id]
}

# EKS VPC Endpoint
resource "aws_vpc_endpoint" "eks" {
  count = var.vpc_endpoints != null && var.vpc_endpoints.eks != null && var.vpc_endpoints.eks.enabled && var.vpc_endpoints.eks.existing_endpoint_id == null ? 1 : 0
  
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${local.region}.eks"
  vpc_endpoint_type   = "Interface"
  
  subnet_ids = length(var.vpc_endpoints.eks.subnet_ids) > 0 ? 
    var.vpc_endpoints.eks.subnet_ids : 
    local.default_endpoint_subnets
    
  security_group_ids = length(var.vpc_endpoints.eks.security_group_ids) > 0 ? 
    var.vpc_endpoints.eks.security_group_ids : 
    local.default_endpoint_security_groups
  
  private_dns_enabled = true  # CRITICAL: enables eks.region.amazonaws.com resolution
  
  policy = var.vpc_endpoints.eks.policy_document
  
  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-endpoint"
    Type = "EKS API Access"
  })
}
```

#### **2.2** - Update EKS Configuration Logic
```hcl
# In modules/ddc-infra/main.tf - pass VPC endpoint info
module "ddc_infra" {
  # Pass VPC endpoint configuration
  vpc_endpoints_config = var.vpc_endpoints
  eks_uses_vpc_endpoint = local.eks_uses_vpc_endpoint
}
```

#### **2.3** - Conditional Proxy Infrastructure
```hcl
# In modules/ddc-infra/eks-proxy.tf - make entire file conditional
locals {
  # Only create proxy if private access AND no VPC endpoint
  create_eks_proxy = (
    var.eks_access_config.mode == "private" || 
    var.eks_access_config.mode == "hybrid"
  ) && !var.eks_uses_vpc_endpoint  # NEW CONDITION
}

# All proxy resources become conditional on create_eks_proxy
resource "aws_lb" "eks_proxy" {
  count = local.create_eks_proxy ? 1 : 0
  # ... existing config
}
```

---

## Phase 3: Example Updates and Documentation 🎯
**Status**: ⏳ PENDING - WAITING FOR PHASE 2
**Objective**: Update examples to showcase VPC endpoints

### Tasks:

#### **3.1** - Update Private Example
```hcl
# examples/private/single-region/main.tf
module "unreal_cloud_ddc" {
  # SIMPLIFIED - no complex proxy config needed
  ddc_infra_config = {
    eks_access_config = {
      mode = "private"  # Simple mode, no proxy settings
    }
  }
  
  # NEW - VPC endpoints replace proxy complexity
  vpc_endpoints = {
    eks = {
      enabled = true  # Eliminates proxy NLB automatically
    }
  }
}
```

#### **3.2** - Create VPC Endpoints Example
```hcl
# examples/private/vpc-endpoints/main.tf
# Showcase full VPC endpoints usage
vpc_endpoints = {
  eks = {
    enabled = true
  }
  ecr_api = {
    enabled = true
  }
  ecr_dkr = {
    enabled = true
  }
  s3 = {
    enabled = true
  }
}
```

#### **3.3** - Update Documentation
- Add VPC endpoints section to README
- Document cost comparison (VPC endpoint vs proxy NLB)
- Migration guide from proxy to VPC endpoints
- Troubleshooting guide for VPC endpoint issues

---

## Phase 4: Advanced VPC Endpoints (Future) 🎯
**Status**: ⏳ PENDING - WAITING FOR PHASE 3
**Objective**: Add support for additional AWS services

### Tasks:

#### **4.1** - ECR Endpoints (Container Registry)
```hcl
# For GHCR/ECR image pulls
resource "aws_vpc_endpoint" "ecr_api" { }
resource "aws_vpc_endpoint" "ecr_dkr" { }
```

#### **4.2** - S3 Gateway Endpoint
```hcl
# For DDC S3 bucket access
resource "aws_vpc_endpoint" "s3" {
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.vpc_endpoints.s3.route_table_ids
}
```

#### **4.3** - Additional Endpoints
- Secrets Manager (for bearer tokens)
- CloudWatch Logs (for logging)
- SSM (for ScyllaDB automation)

---

## 🚀 IMMEDIATE NEXT STEPS:

### **PRIORITY 1: Design and Validate**
1. **Finalize variable structure** - Review and approve VPC endpoints design
2. **Create validation logic** - Prevent conflicting configurations
3. **Plan migration strategy** - Backward compatibility approach

### **PRIORITY 2: Core Implementation**
1. **Implement EKS VPC endpoint** - Primary focus, biggest impact
2. **Update proxy logic** - Make conditional on VPC endpoint usage
3. **Test private access** - Verify kubectl works through VPC endpoint

### **PRIORITY 3: Examples and Documentation**
1. **Update private example** - Showcase VPC endpoint simplicity
2. **Create migration guide** - Help users transition from proxy
3. **Document cost savings** - VPC endpoint vs proxy NLB comparison

---

## 📈 SUCCESS METRICS:
- ✅ **Eliminate proxy complexity** - Remove 200+ lines of proxy infrastructure code
- ✅ **Cost reduction** - Save ~$9/month per deployment (NLB vs VPC endpoint)
- ✅ **Security improvement** - No internet egress required for AWS APIs
- ✅ **Simplified configuration** - Single boolean vs complex proxy object
- ✅ **Backward compatibility** - Existing configurations continue working
- ✅ **Future ready** - Foundation for additional VPC endpoints

**This implementation delivers:**
- ✅ **Massive simplification** - Eliminate complex EKS proxy infrastructure
- ✅ **Better security** - True private AWS API access without internet
- ✅ **Cost optimization** - Lower monthly costs with better functionality
- ✅ **AWS best practices** - Use native VPC endpoints instead of workarounds
- ✅ **User choice** - Flexible per-service endpoint control
- ✅ **Migration path** - Smooth transition from current proxy approach