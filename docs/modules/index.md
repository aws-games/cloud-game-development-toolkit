---
title: Modules
description: Terraform modules for game development on AWS
---

# Modules

## Introduction

A module is an automated deployment of a game development workload (i.e. Jenkins, P4 Server, Unreal Horde) that is implemented as a Terraform module. They are designed to provide flexibility and customization via input variables with defaults based on typical deployment architectures. They are designed to be depended on from other modules (including your own root module), easily integrate with each other, and provide relevant outputs to simplify permissions, networking, and access.

> Note: While the project focuses on Terraform modules today, this project may expand to provide options for implementations built in other IaC tools such as AWS CDK in the future.

## Getting Started

### Module Source Options

**Option 1: Git Release Tag (Recommended)**
```hcl
module "example_module" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/path/to/module?ref=v1.2.0"
  # ... configuration
}
```

**Option 2: Specific Commit Hash**
```hcl
module "example_module" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/path/to/module?ref=abc123def456"
  # ... configuration (replace abc123def456 with actual commit hash)
}
```

### Basic Usage Pattern

```hcl
module "service" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/service-name?ref=v1.2.0"
  
  # Access method
  access_method = "external"  # or "internal"
  
  # Networking
  vpc_id = aws_vpc.main.id
  public_subnets = aws_subnet.public[*].id
  private_subnets = aws_subnet.private[*].id
  
  # Security
  allowed_external_cidrs = ["203.0.113.0/24"]  # Your office network
  
  # Service-specific configuration
  # ... see individual module documentation
}
```

## Available Modules

!!! info
    **Don't see a module listed?** Create a [feature request](https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE) for a new module. If you'd like to contribute new modules to the project, see the [general docs on contributing](../../CONTRIBUTING.md).

| Module | Description | Status |
| :--------------------------------------------------------------- | :- | :- |
| [:simple-perforce: __Perforce__](../../modules/perforce/README.md) | This module allows for deployment of Perforce resources on AWS. These are currently P4 Server (formerly Helix Core), P4Auth (formerly Helix Authentication Service), and P4 Code Review (formerly Helix Swarm). | ✅ External Access |
| [:simple-unrealengine: __Unreal Horde__](../../modules/unreal/horde/README.md) | This module allows for deployment of Unreal Horde on AWS. | ✅ External Access |
| [:simple-unrealengine: __Unreal Cloud DDC__](../../modules/unreal/unreal-cloud-ddc/README.md) | This module allows for deployment of Unreal Cloud DDC (Derived Data Cache) on AWS. | ✅ External Access |
| [:simple-jenkins: __Jenkins__](../../modules/jenkins/README.md) | This module allows for deployment of Jenkins on AWS. | ✅ External Access |
| [:simple-teamcity: __TeamCity__](../../modules/teamcity/README.md) | This module allows for deployment of TeamCity resources on AWS. | ✅ External Access |
| 🖥️ __VDI (Virtual Desktop Interface)__ | Virtual desktop infrastructure for game development teams. | 🔜 Coming Soon |
| __Monitoring__ | Pending development - will provide unified monitoring across all CGD services. | 🚧 Future |

**Note**: Current modules support external access with secured multi-layer security. Internal access patterns are planned for future releases.

## Module Architecture

### Parent Modules and Submodules

The toolkit uses a **parent module with submodules** pattern for complex services with distinct components or boundaries. This structure is designed for contributing developers and internal module organization.

**General Structure:**
```
modules/
├── service-name/
│   ├── main.tf              # Parent module orchestration
│   ├── modules/
│   │   ├── component-a/     # Submodule for distinct component
│   │   └── component-b/     # Submodule for separate concerns
│   └── examples/
│       └── complete/        # Shows parent module usage
```

**Configuration Flow:**
Configuration flows from example → parent module → submodules, enabling granular control.

```
Example Level:
├── terraform.tfvars (user defines requirements)
├── main.tf (calls parent module with config)
│
Parent Module Level:
├── variables.tf (defines configuration objects)
├── main.tf (orchestrates submodules and creates shared infrastructure)
│
Submodule Level:
├── variables.tf (receives specific configuration)
├── main.tf (implements actual resources)
```

## Design Standards

The Cloud Game Development Toolkit follows **opinionated but flexible** design principles to provide game studios with proven patterns while allowing customization for specific needs.

### Core Tenets

- **Serverless First**: Prefer managed services and serverless technologies where possible
- **Container First**: Use ECS/EKS for scalable, maintainable services
- **Security by Default**: Implement least privilege access and private-first networking
- **Deep Customization**: Provide extensive configuration options while maintaining sensible defaults
- **Integration Ready**: Design modules to work together seamlessly

### Compute Strategy

**Preference Order:**
1. **Serverless** (Lambda, Fargate) - Preferred for simplicity and cost
2. **Managed Containers** (ECS Fargate, EKS Fargate) - For scalable services
3. **Container Orchestration** (ECS EC2, EKS EC2) - When Fargate limitations apply
4. **Dedicated EC2** - Only when technology requirements mandate it

### Networking Architecture

**Private-First Design:**
- Services always deployed in private subnets
- User access method determines load balancer placement
- **NLB-First Strategy**: All traffic routed through load balancers (preferred pattern, may deviate when required)

**Access Method Control:**
All modules support configurable access patterns via `access_method` variable:

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

**External Access (Default):**
```hcl
access_method = "external"  # or "public"
```
```
Internet Users → Public NLB → NLB Target (ALB, EKS, EC2, etc.)
```
- **Creates**: Conditional public NLB (users can supply existing load balancers)
- **DNS**: Regional endpoints (us-east-1.service.example.com)
- **Certificates**: ACM certificates with DNS validation via public zone
- **Security**: Restricted CIDR blocks or managed prefix lists (no 0.0.0.0/0)
- **Connection**: Users connect via public internet with controlled access

**Internal Access:**
```hcl
access_method = "internal"  # or "private"
```
```
VPN/VDI Users → Private NLB → NLB Target (ALB, EKS, EC2, etc.)
```
- **Creates**: Conditional private NLB (users can supply existing load balancers)
- **DNS**: Regional endpoints (us-east-1.service.internal)
- **Certificates**: [AWS Private CA](https://aws.amazon.com/private-ca/) certificates for internal domains
- **Security**: VPC CIDR blocks for automatic inclusion of VPC resources
- **Connection**: Users need VPC access via:
  - AWS Client VPN
  - Site-to-Site VPN
  - AWS Direct Connect
  - VDI/Bastion hosts

### Security Architecture

**Layered Security Groups:**
- **Pattern 1**: NLB → ALB → Service (3 layers, e.g., Perforce web services)
- **Pattern 2**: NLB → Service (2 layers, e.g., EKS direct access)

**Security Group Best Practices:**
- **Separate rule resources**: Use `aws_security_group_rule` (not inline rules)
- **No 0.0.0.0/0**: Validation prevents open access
- **Prefix lists recommended**: For managing multiple IP ranges without Terraform changes
- **Combined security groups**: Module SGs + user-provided additional SGs

**External Access Security:**
```hcl
variable "allowed_external_cidrs" {
  type = list(string)
  description = "CIDR blocks for external access. Use prefix lists for multiple IPs."
  validation {
    condition = !contains(var.allowed_external_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed for security. Specify actual CIDR blocks."
  }
}
```

**Internal Access Security:**
```hcl
# VPC CIDR automatically includes all VPC resources
cidr_blocks = [data.aws_vpc.main.cidr_block]
# Alternative: Use dedicated security groups for enhanced security and control
```

### DNS Strategy

**Regional Endpoints (Recommended):**
- **External**: `us-east-1.service.example.com`, `us-west-2.service.example.com`
- **Internal**: `us-east-1.service.internal`, `us-west-2.service.internal`
- **Benefits**: Clear regional separation, manual DR control, simplified routing

**Private Hosted Zones (Always Created):**
```hcl
# Dynamic naming based on access method
locals {
  private_zone_name = local.is_external_access ? 
    "service.${var.public_domain}" :  # External: service.example.com
    "service.internal"               # Internal: service.internal
}
```

**DNS Record Creation:**
- **Public records**: Created at example level (safer, no module impact on public zones)
- **Private records**: Created in module for internal service routing
- **Multi-region**: VPC associations for cross-region private DNS access

### Certificate Management

**Certificate Requirements by Access Method:**

| Access Method | Domain Type | Certificate Source | Validation | Browser Warnings | Status |
|---------------|-------------|-------------------|------------|------------------|---------|
| external | service.example.com | ACM | DNS (public zone) | ❌ None | ✅ Supported |
| internal | service.internal | [AWS Private CA](https://aws.amazon.com/private-ca/) | Internal CA | ⚠️ Yes (unless CA trusted) | 🚧 Future |
| internal | service.internal | Self-signed | None | ⚠️ Yes (always) | 🚧 Future |

#### External Access (`access_method = "external"`)
**Requirements:**
- Must own a public domain (e.g., `example.com`)
- Public Route53 hosted zone (subdomain delegation supported)

**Public Zone Setup Options:**

**REQUIREMENT**: A public Route53 hosted zone is required for external access. Third-party DNS providers are supported via subdomain delegation.

```bash
# Option 1: Full domain in Route53
# Create Route53 public zone: example.com

# Option 2: Subdomain delegation from third-party DNS (recommended)
# 1. Create Route53 public zone: gamedev.example.com
# 2. Add NS delegation in your external DNS provider: gamedev.example.com → Route53 nameservers
# 3. Configure module: public_hosted_zone_name = "gamedev.example.com"
```

**Third-Party DNS Integration**: If you use providers like Cloudflare, GoDaddy, or Namecheap, create a subdomain delegation to Route53. This allows modules to manage certificates and DNS records while keeping your primary domain with your preferred provider.

**Certificate Creation (Example Level):**
```hcl
# examples/complete/dns.tf - NOT in module
resource "aws_acm_certificate" "service" {
  domain_name = "*.service.${var.public_domain}"
  
  # SAN entries for complex domains
  subject_alternative_names = [
    "service.${var.public_domain}",
    "*.us-east-1.service.${var.public_domain}",
    "*.us-west-2.service.${var.public_domain}"
  ]
  
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.service.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  
  zone_id = data.aws_route53_zone.public.id
  name    = each.value.name
  records = [each.value.record]
  ttl     = 60
  type    = each.value.type
}

resource "aws_acm_certificate_validation" "service" {
  certificate_arn = aws_acm_certificate.service.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Pass validated certificate to module
module "service" {
  certificate_arn = aws_acm_certificate_validation.service.certificate_arn
}
```

#### Internal Access (`access_method = "internal"`)
**Certificate Creation (Module Level - Future):**
```hcl
# Private CA certificate for internal domains
resource "aws_acmpca_certificate" "internal" {
  domain_name = "*.service.internal"
  # Certificate authority integration
}
```

**Browser Warning Resolution:**
Internal certificates require installing the Private CA root certificate in client trust stores. See [AWS Private CA documentation](https://docs.aws.amazon.com/privateca/latest/userguide/PcaWelcome.html) for client configuration.

### Terraform Access Patterns

**Access Source Considerations:**

| Environment | Access Type | IP Source | Security Consideration |
|-------------|-------------|-----------|----------------------|
| **Local Dev** | External | Your public IP | Add to `allowed_external_cidrs` |
| **GitHub Actions** | External | GitHub's public IPs | Use GitHub's published IP ranges |
| **CodeBuild (default)** | External | AWS public IPs | Use CodeBuild's IP ranges |
| **CodeBuild (VPC)** | Internal | VPC private IPs | Automatically covered by VPC CIDR |
| **EC2/ECS** | Internal | VPC private IPs | Automatically covered by VPC CIDR |

**EKS API Access** (relevant for modules using Helm and Kubernetes providers, e.g., Unreal Cloud DDC):
```hcl
# Dynamic IP detection for Terraform access
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

variable "eks_api_access_cidrs" {
  description = "CIDR blocks for EKS API access. Include your current IP, CI/CD systems, etc."
  default = []
}
```

**Important**: If your physical location changes or your IP may have changed, re-run `terraform apply` to update your IP for EKS API access. We recommend using a data source for dynamic IP detection as it will be checked during each plan operation.

## Advanced Configuration

### Multi-Region Architecture

**Regional Isolation Pattern:**
- **Separate module instances** per region
- **Regional endpoints** for user control
- **Manual disaster recovery** (users switch endpoints)
- **Cross-region connectivity** via VPC peering or Transit Gateway

**Example Multi-Region Setup:**

We leverage Terraform's [enhanced AWS provider region support](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#multiple-provider-configurations) for multi-region deployments. Currently, only the AWS provider supports this enhanced region handling. Other providers (Kubernetes, Helm) still require explicit provider configuration. We are tracking provider updates and will adopt enhanced region support for other providers as it becomes available.

```hcl
# Primary region
module "ddc_primary" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc?ref=v1.2.0"
  
  # Enhanced region support - AWS provider auto-inherited
  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
    # AWS provider automatically inherited based on region
  }
  
  region = var.primary_region
  vpc_id = aws_vpc.primary.id
  
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
  vpc_id = aws_vpc.secondary.id
  
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



### Traffic Flow Patterns

**HTTP Traffic Flow (External Access):**
```
User → DNS Resolution → Public NLB (TCP:80) → EKS Service → Application Pod
```

**HTTPS Traffic Flow (External Access):**
```
User → DNS Resolution → Public NLB (SSL termination, TCP:443) → EKS Service → Application Pod
```

**Internal Access Pattern:**
```
VPN User → DNS Resolution → Private NLB (TCP:80/443) → EKS Service → Application Pod
```

**SSL Termination Options:**
- **NLB SSL Termination**: Certificate attached to NLB (current approach)
- **Application SSL**: Certificate managed by Kubernetes Ingress (alternative)

### Private Hosted Zone Usage

**When Private Hosted Zones Are Required:**
- **Multiple Services**: When routing different subdomains to different services (e.g., Perforce: `auth.perforce.com`, `review.perforce.com`)
- **Internal ALB**: When using ALB behind NLB for advanced routing
- **Cross-Service Communication**: When services need to discover each other via DNS
- **Multi-Region Replication**: When services in different regions communicate

**When Private Hosted Zones Are Optional:**
- **Single Service**: Direct NLB to single service (e.g., current DDC implementation)
- **External Access Only**: No internal service-to-service communication
- **IP-Based Communication**: Services use direct IPs instead of DNS

**Current Module Implementations:**
- **DDC**: Private zone created but currently unused (future-proofing)
- **Perforce**: Private zone required for multiple web services routing
- **Jenkins/TeamCity**: Private zone used for internal service discovery

**Why NLB-First Strategy:**
- **Consistent security model**: All traffic through load balancers
- **Better observability**: NLB access logs and CloudWatch metrics
- **Health checking**: NLB can detect service failures
- **Future flexibility**: Can add multiple targets behind NLB
- **Cost optimization**: Remove EIP dependencies

**Note**: Some modules use ALB behind NLB for advanced routing, but direct NLB-to-EKS is preferred for simplicity.

## Contributing

For detailed information on contributing new modules or enhancing existing ones, see the [general docs on contributing](../../CONTRIBUTING.md).

**Module Structure Standards**: The parent module with submodules pattern described in the Module Architecture section is our standard approach for complex services with multiple components.