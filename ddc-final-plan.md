# DDC Module Standardization - Final Implementation Plan

## Overview
This document outlines the comprehensive changes needed to align the Unreal Cloud DDC module with the new CGD Toolkit networking and security standards.

## Current State Analysis

### ✅ Already Implemented
- **Conditional submodule architecture** - Parent module with ddc-infra, ddc-monitoring, ddc-services
- **NLB-first strategy** - Traffic routes through load balancers (no direct EIPs)
- **Private subnet deployment** - Services in private subnets
- **Security group layering** - Module SGs + user additional SGs
- **Private hosted zone creation** - Basic internal DNS
- **EKS API access variables** - `eks_api_access_cidrs` already exists in `ddc_infra_config`
- **Load balancer access logs** - ALB access logs already configurable
- **Multi-region support** - Existing `shared_private_zone_id` pattern for cross-region DNS
- ✅ **Access Method Standardization** - Added `access_method` variable with external/internal options
- ✅ **Security Group Rule Pattern** - Converted from `aws_vpc_security_group_egress_rule` to standard `aws_security_group_rule`
- ✅ **Hardcoded CIDR Blocks** - Replaced hardcoded `10.0.0.0/8` with dynamic VPC CIDR detection
- ✅ **Regional Tags** - Added `Region = var.region` tag to all resources
- ✅ **DNS Strategy Implementation** - Added private hosted zones with conditional public DNS
- ✅ **Multi-region DNS Support** - Added `shared_private_zone_id` output and cross-region VPC associations
- ✅ **Dynamic Zone Naming** - Implemented access method-based zone naming (ddc.example.com vs ddc.internal)
- ✅ **Load Balancer Access Logs** - Added NLB access logs support with S3 bucket creation
- ✅ **Complete Regional Tagging** - Added `Region = var.region` to all remaining resources
- ✅ **Output Standardization** - Added comprehensive module outputs for access method, security groups, load balancers, and configuration summary
- ✅ **Multi-region Output Support** - Added `shared_private_zone_id` and standardized outputs for cross-region integration
- ✅ **Monitoring Submodule Removal** - Removed all monitoring references from core module (dedicated monitoring module planned)
- ✅ **Security Group Clarity** - Reverted from over-abstracted single SG to clear external/internal separation with DRY where appropriate
- ✅ **Load Balancer DRY** - Single `shared_nlb` resource with conditional configuration (internal/external)
- ✅ **Certificate Management** - Moved to example level per design standards
- ✅ **Public DNS Removal** - Removed from module, handled at example level per Perforce pattern

### ✅ **IMPLEMENTATION COMPLETE** - All Standards Compliance Achieved

## ✅ **All Gaps Resolved**

### ✅ **Security Group Rule Pattern** - COMPLETED
**Resolution**: Converted all `aws_vpc_security_group_egress_rule` to standard `aws_security_group_rule`

### ✅ **Hardcoded CIDR Blocks** - COMPLETED
**Resolution**: Replaced hardcoded `10.0.0.0/8` with dynamic VPC CIDR detection using `data.aws_vpc.main`
- **Egress to 0.0.0.0/0**: Maintained for acceptable outbound internet access
- **Ingress from 0.0.0.0/0**: Blocked with validation in `allowed_external_cidrs`

### ✅ **Regional Tags** - COMPLETED
**Resolution**: Added `Region = var.region` tag to all resources consistently

### ✅ **EKS API Access Variables** - COMPLETED
**Resolution**: Added `data.http.my_ip` for dynamic IP detection helper

## Required Changes

### 1. Access Method Standardization

**Current Issue:** No `access_method` variable - hardcoded to external access only

**Required Changes:**
```hcl
# Add to variables.tf
variable "access_method" {
  type = string
  description = "external/public: Internet → Public NLB | internal/private: VPC → Private NLB"
  default = "external"
  
  validation {
    condition = contains(["external", "internal", "public", "private"], var.access_method)
    error_message = "Must be 'external'/'public' or 'internal'/'private'"
  }
}

# Add to locals.tf
locals {
  is_external_access = contains(["external", "public"], var.access_method)
  name_prefix = "${var.project_prefix}-${var.ddc_infra_config != null ? var.ddc_infra_config.name : "ddc"}"
}
```

### 2. Load Balancer Conditional Creation (Parent Module Level)

**Current Issue:** NLB hardcoded as `internal = false`, ALB controlled by `internal_facing_application_load_balancer` variable

**Required Changes:**
```hcl
# Update lb.tf
resource "aws_lb" "external_shared_nlb" {
  count              = local.is_external_access && var.ddc_infra_config != null ? 1 : 0
  name_prefix        = "${var.project_prefix}-"
  load_balancer_type = "network"
  internal           = false
  subnets            = var.public_subnets
  
  security_groups = concat(
    [aws_security_group.external_shared_nlb[0].id],
    var.existing_security_groups,
    var.ddc_infra_config.additional_nlb_security_groups
  )
  
  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-external-shared-nlb"
    Type   = "Network Load Balancer"
    Access = "External"
    Region = var.region
  })
}

resource "aws_lb" "internal_shared_nlb" {
  count              = !local.is_external_access && var.ddc_infra_config != null ? 1 : 0
  name_prefix        = "${var.project_prefix}-"
  load_balancer_type = "network"
  internal           = true
  subnets            = var.private_subnets
  
  security_groups = concat(
    [aws_security_group.internal_shared_nlb[0].id],
    var.existing_security_groups,
    var.ddc_infra_config.additional_nlb_security_groups
  )
  
  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-internal-shared-nlb"
    Type   = "Network Load Balancer"
    Access = "Internal"
    Region = var.region
  })
}

# ALB always internal (behind NLB)
resource "aws_lb" "shared_alb" {
  count              = var.ddc_monitoring_config != null ? 1 : 0
  name_prefix        = "${var.project_prefix}-"
  load_balancer_type = "application"
  internal           = true  # Always internal
  subnets            = var.private_subnets
  
  tags = merge(var.tags, {
    Name   = "${local.name_prefix}-shared-alb"
    Type   = "Application Load Balancer"
    Access = "Internal"
    Region = var.region
  })
}
```

### 3. Security Group Standardization

**Current Issue:** Uses `aws_vpc_security_group_egress_rule`, hardcoded CIDRs, no 0.0.0.0/0 ingress validation

**Required Changes:**
```hcl
# Add new variables
variable "allowed_external_cidrs" {
  type = list(string)
  description = "CIDR blocks for external access. Use prefix lists for multiple IPs."
  default = []
  
  validation {
    condition = !contains(var.allowed_external_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed for ingress. Specify actual CIDR blocks or use prefix lists."
  }
}

# EKS API access already exists in ddc_infra_config.eks_api_access_cidrs
# Just need to add dynamic IP detection helper

# Dynamic IP detection (optional)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

variable "external_prefix_list_id" {
  type = string
  description = "Managed prefix list ID for external access (recommended for multiple IPs)"
  default = null
}

variable "public_subnets" {
  type = list(string)
  description = "Public subnet IDs for external load balancers"
  default = []
}

variable "private_subnets" {
  type = list(string)
  description = "Private subnet IDs for internal load balancers and services"
  default = []
}

# Convert from aws_vpc_security_group_egress_rule to aws_security_group_rule
resource "aws_security_group" "external_shared_nlb" {
  count = local.is_external_access ? 1 : 0
  name  = "${var.project_prefix}-external-shared-nlb-sg"
  vpc_id = var.vpc_id
  
  tags = merge(var.tags, {
    Name   = "${var.project_prefix}-external-shared-nlb-sg"
    Type   = "External NLB"
    Region = var.region  # Added regional tag
  })
}

# Ingress rules (no 0.0.0.0/0 allowed)
resource "aws_security_group_rule" "external_nlb_http_cidrs" {
  count             = local.is_external_access && length(var.allowed_external_cidrs) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_external_cidrs
  security_group_id = aws_security_group.external_shared_nlb[0].id
}

# Egress rules (0.0.0.0/0 acceptable for outbound)
resource "aws_security_group_rule" "external_nlb_egress_all" {
  count             = local.is_external_access ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]  # Acceptable for egress
  security_group_id = aws_security_group.external_shared_nlb[0].id
}

resource "aws_security_group_rule" "external_nlb_http_prefix" {
  count             = local.is_external_access && var.external_prefix_list_id != null ? 1 : 0
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  prefix_list_ids   = [var.external_prefix_list_id]
  security_group_id = aws_security_group.external_shared_nlb[0].id
}

resource "aws_security_group" "internal_shared_nlb" {
  count = !local.is_external_access ? 1 : 0
  name  = "${var.project_prefix}-internal-shared-nlb-sg"
  vpc_id = var.vpc_id
  
  tags = merge(var.tags, {
    Name   = "${var.project_prefix}-internal-shared-nlb-sg"
    Type   = "Internal NLB"
    Region = var.region
  })
}

# Use dynamic VPC CIDR instead of hardcoded ranges
data "aws_vpc" "main" {
  id = var.vpc_id
}

resource "aws_security_group_rule" "internal_nlb_vpc_access" {
  count             = !local.is_external_access ? 1 : 0
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.main.cidr_block]  # Dynamic VPC CIDR
  security_group_id = aws_security_group.internal_shared_nlb[0].id
}
```

### 4. DNS Strategy Implementation

**Current Issue:** Static private zone naming, needs integration with existing `shared_private_zone_id` pattern

**Required Changes:**
```hcl
# Update route53.tf
locals {
  # Dynamic private zone naming based on access method
  private_zone_name = local.is_external_access ? 
    "ddc.${var.public_domain}" :     # External: ddc.example.com
    "ddc.internal"                   # Internal: ddc.internal
}

# Add new variables
variable "public_domain" {
  type = string
  description = "Public domain name for external access (e.g., example.com)"
  default = null
}

variable "additional_vpc_associations" {
  type = map(object({
    vpc_id = string
    region = string
  }))
  description = "Additional VPCs to associate with private zone (for cross-region access)"
  default = {}
}

variable "is_primary_region" {
  type = bool
  description = "Whether this is the primary region (for future use)"
  default = true
}

# Update private zone creation (integrate with existing logic)
resource "aws_route53_zone" "ddc_private_hosted_zone" {
  count = var.create_route53_private_hosted_zone && var.shared_private_zone_id == null ? 1 : 0
  name  = local.private_zone_name
  
  vpc {
    vpc_id = var.vpc_id
  }
  
  tags = merge(var.tags, {
    Name   = "${var.project_prefix}-ddc-private-zone"
    Type   = "Private"
    Region = var.region
  })
}

# Multi-region VPC associations (integrate with existing pattern)
resource "aws_route53_zone_association" "cross_region_vpcs" {
  for_each = var.additional_vpc_associations
  
  zone_id    = var.shared_private_zone_id != null ? var.shared_private_zone_id : aws_route53_zone.ddc_private_hosted_zone[0].id
  vpc_id     = each.value.vpc_id
  vpc_region = each.value.region
}

# Maintain existing shared zone association pattern
resource "aws_route53_zone_association" "ddc_private_secondary" {
  count      = var.shared_private_zone_id != null ? 1 : 0
  zone_id    = var.shared_private_zone_id
  vpc_id     = var.vpc_id
  vpc_region = var.region
}
```

### 5. Simplified Outputs with Static Values

**Current Issue:** Complex nested outputs, no direct regional endpoint access

**Required Changes:**
```hcl
# Update outputs.tf - simplified structure with static values
output "regional_endpoint" {
  description = "Regional endpoint for DDC service (known at plan time)"
  value = var.region != null ? "${var.region}.ddc.${var.public_domain != null ? var.public_domain : "internal"}" : null
}

output "nlb_dns_name" {
  description = "NLB DNS name for regional endpoint"
  value = local.is_external_access ? 
    try(aws_lb.external_shared_nlb[0].dns_name, null) :
    try(aws_lb.internal_shared_nlb[0].dns_name, null)
}

output "nlb_zone_id" {
  description = "NLB zone ID for regional endpoint"
  value = local.is_external_access ? 
    try(aws_lb.external_shared_nlb[0].zone_id, null) :
    try(aws_lb.internal_shared_nlb[0].zone_id, null)
}

# Keep regional distinction for UX
output "connection_info" {
  description = "DDC connection information with regional context"
  value = {
    region = var.region
    endpoint = var.region != null ? "${var.region}.ddc.${var.public_domain != null ? var.public_domain : "internal"}" : null
    nlb_dns = local.is_external_access ? 
      try(aws_lb.external_shared_nlb[0].dns_name, null) :
      try(aws_lb.internal_shared_nlb[0].dns_name, null)
    access_method = var.access_method
  }
}
```

### 6. Example Level Updates

**Current Issue:** Examples don't follow new DNS patterns

**Required Changes:**
```hcl
# Update examples/single-region/dns.tf
# Regional endpoint (always created)
resource "aws_route53_record" "ddc_regional" {
  zone_id = data.aws_route53_zone.public.id
  name    = "${var.region}.ddc.${var.public_domain}"
  type    = "A"
  
  alias {
    name                   = module.unreal_cloud_ddc.nlb_dns_name
    zone_id                = module.unreal_cloud_ddc.nlb_zone_id
    evaluate_target_health = true
  }
}

# Update examples/single-region/main.tf
module "unreal_cloud_ddc" {
  source = "../../"
  
  # New standardized variables
  access_method = "external"  # or "internal"
  region = var.region
  
  # Subnet configuration
  public_subnets  = aws_subnet.public_subnets[*].id
  private_subnets = aws_subnet.private_subnets[*].id
  
  # Security configuration
  allowed_external_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]
  
  # DNS configuration
  public_domain = var.route53_public_hosted_zone_name
  
  # Existing configuration...
  vpc_id = aws_vpc.unreal_cloud_ddc_vpc.id
  existing_security_groups = [aws_security_group.allow_my_ip.id]
}
```

### 7. Multi-Region Example

**Required Changes:**
```hcl
# Create examples/multi-region/main.tf
# Primary region
module "ddc_primary" {
  source = "../../"
  
  access_method = "external"
  region = "us-east-1"
  is_primary_region = true
  
  public_subnets  = aws_subnet.primary_public_subnets[*].id
  private_subnets = aws_subnet.primary_private_subnets[*].id
  
  allowed_external_cidrs = var.allowed_external_cidrs
  public_domain = var.route53_public_hosted_zone_name
  
  # DDC configuration...
}

# Secondary region
module "ddc_secondary" {
  source = "../../"
  
  providers = {
    aws = aws.secondary
  }
  
  access_method = "external"
  region = "us-west-2"
  is_primary_region = false
  
  public_subnets  = aws_subnet.secondary_public_subnets[*].id
  private_subnets = aws_subnet.secondary_private_subnets[*].id
  
  allowed_external_cidrs = var.allowed_external_cidrs
  public_domain = var.route53_public_hosted_zone_name
  
  # Cross-region VPC association
  additional_vpc_associations = {
    primary_vpc = {
      vpc_id = module.ddc_primary.vpc_id
      region = "us-east-1"
    }
  }
  
  # DDC configuration with replication...
  ddc_services_config = {
    ddc_replication_region_url = "https://us-east-1.ddc.${var.route53_public_hosted_zone_name}"
    # Other config...
  }
}
```

## Implementation Priority

### Phase 1: Core Infrastructure (High Priority)
1. **Access method variable** - Foundation for all other changes
2. **Load balancer conditional creation** - External vs internal NLBs
3. **Security group standardization** - Separate rules, no 0.0.0.0/0
4. **Subnet variables** - Public vs private subnet separation

### Phase 2: DNS & Regional Support (Medium Priority)
1. **Dynamic private zone naming** - Based on access method
2. **Regional endpoint outputs** - Support for regional DNS patterns
3. **Multi-region VPC associations** - Cross-region private DNS

### Phase 3: Examples & Documentation (Low Priority)
1. **Update single-region example** - New variable patterns
2. **Create multi-region example** - Demonstrate cross-region setup
3. **Update documentation** - Reflect new standards

## Breaking Changes

### Variables
- **New required**: `public_subnets`, `private_subnets`
- **New optional**: `access_method`, `allowed_external_cidrs`, `public_domain`
- **Changed behavior**: `existing_security_groups` now combined with module SGs

### Outputs
- **New**: `regional_endpoint`, `nlb_dns_name`, `nlb_zone_id`
- **Changed**: Load balancer outputs now conditional based on access method

### DNS
- **Private zone naming**: Now dynamic based on access method
- **Regional endpoints**: New pattern `us-east-1.ddc.example.com`

## Testing Requirements

### Functional Testing
1. **External access**: Internet → Public NLB → EKS services
2. **Internal access**: VPN → Private NLB → EKS services
3. **Multi-region**: Cross-region replication and DNS resolution
4. **Security groups**: Proper layering and access control

### Security Testing
1. **No 0.0.0.0/0**: Validation prevents open access
2. **Prefix lists**: Multiple IP management without Terraform changes
3. **VPC CIDR**: Automatic inclusion of VPC resources for internal access

### Performance Testing
1. **Regional endpoints**: Latency comparison across regions
2. **Load balancer health checks**: Proper failover behavior
3. **DNS resolution**: Private zone performance across VPCs

## Migration Guide

### For Existing Users
1. **Add new variables**: `public_subnets`, `private_subnets`, `allowed_external_cidrs`
2. **Update security groups**: Remove any 0.0.0.0/0 CIDRs
3. **Update DNS records**: Switch to regional endpoint pattern
4. **Test access**: Verify external/internal access patterns work

### Backward Compatibility
- **Default behavior**: `access_method = "external"` maintains current functionality
- **Existing variables**: All current variables remain supported
- **Gradual migration**: Users can adopt new patterns incrementally

This comprehensive plan ensures the DDC module aligns with CGD Toolkit standards while maintaining backward compatibility and providing clear migration paths for existing users.