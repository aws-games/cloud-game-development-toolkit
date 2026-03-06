# Modules

## Introduction

A module is an automated deployment of a game development workload (i.e. Perforce, Unreal Horde, Unreal Cloud DDC, etc.) that is implemented as a Terraform module. They are designed to provide flexibility and customization via input variables with defaults based on typical deployment architectures. They are designed to be depended on from other modules (including your own root module), easily integrate with each other, and provide relevant outputs to simplify permissions, networking, and access.

> Note: While the project focuses on Terraform modules today, this project may expand to provide options for implementations built in other IaC tools such as AWS CDK in the future.

## Available Modules

**Don't see a module listed?** Create a [feature request](https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE) for a new module. If you'd like to contribute new modules to the project, see the [general docs on contributing](../CONTRIBUTING.md).

| Module                                                                            | Description                                                                                                                                                                                                     | Status             |
| :-------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------- |
| [:simple-perforce: **Perforce**](./perforce/README.md)                            | This module allows for deployment of Perforce resources on AWS. These are currently P4 Server (formerly Helix Core), P4Auth (formerly Helix Authentication Service), and P4 Code Review (formerly Helix Swarm). | ✅ External Access |
| [:simple-unrealengine: **Unreal Horde**](./unreal/horde/README.md)                | This module allows for deployment of Unreal Horde on AWS.                                                                                                                                                       | ✅ External Access |
| [:simple-unrealengine: **Unreal Cloud DDC**](./unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra/README.md) | This module allows for deployment of Unreal Cloud DDC (Derived Data Cache) on AWS.                                                                                                                              | ✅ External Access |
| [:simple-jenkins: **Jenkins**](./jenkins/README.md)                               | This module allows for deployment of Jenkins on AWS.                                                                                                                                                            | ✅ External Access |
| [:simple-teamcity: **TeamCity**](./teamcity/README.md)                            | This module allows for deployment of TeamCity resources on AWS.                                                                                                                                                 | ✅ External Access |
| [🖥️ **VDI (Virtual Desktop Infrastructure)**](./vdi/README.md)                      | This module allows for deployment of Virtual Desktop Infrastructure (VDI) workstations on AWS with Amazon DCV remote access for game development teams.                                                        | ✅ External Access |
| **Monitoring**                                                                    | Pending development - will provide unified monitoring across all CGD services.                                                                                                                                  | 🚧 Future          |

## Getting Started

### Module Source Options

Due to the structure of the toolkit, all modules will have unified incremental versions during our release process. To reference a specific version, simply have a different source on a module-by-module basis. The same applies to the commit hash option (though less clear to track changes so not recommended for most users).

Important, currently there is a staggered release process. When a PR is merged to main, that doesn't immediately trigger a new release. **⚠️ should we be doing this still?**

**Option 1: Git Release Tag (Recommended ✅)**
Use case: Explicit version tracking. Easy to pin to specific versions of modules.

```hcl
module "example_module" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/path/to/module?ref=v1.1.5"
  # ... configuration
}
```

**Option 2: Specific Commit Hash**
Use case: If you want the latest and greatest, even before a release may be cut. As such we recommend caution with this option as well.

```hcl
module "example_module" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/path/to/module?ref=abc123def456"
  # ... configuration (replace abc123def456 with actual commit hash)
}
```

**Option 3: Git Branch (⚠️ Caution)**
Use case: If you don't care about tracking versions and just want to use whatever is the latest. Due to the fact that you cant track versions with this, we recommend high caution using this method.

```hcl
module "example_module" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/path/to/module?ref=main"
  # ... configuration
}
```

**Option 4: Submodule Reference**
You can also include the **CGD Toolkit** repository as a git submodule in your own infrastructure repository as a way of depending on the modules within an (existing) Terraform root module. Forking the **CGD Toolkit** and submoduling your fork may be a good approach if you intend to make changes to any modules. We recommend starting with the [Terraform module documentation](https://developer.hashicorp.com/terraform/language/modules) for a crash course in the way patterns that influence the way that the **CGD Toolkit** is designed. Note how you can use the [module source argument](https://developer.hashicorp.com/terraform/language/modules/sources) to declare modules that use the **CGD Toolkit**'s module source code.

### Basic Usage Pattern

```hcl
module "service" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/service-name?ref=v1.2.0"

  # Networking (3-tier architecture)
  application_subnets = var.private_subnets  # Primary business applications
  service_subnets    = var.private_subnets   # Supporting services (databases, caches)

  # Load balancer configuration
  load_balancer_config = {
    nlb = {
      internet_facing = true               # External access
      subnets        = var.public_subnets  # Load balancer placement
    }
    # ALB optional - module-specific support
  }

  # Security
  security_groups = [aws_security_group.office_access.id]

  # Service-specific configuration
  # ... see individual module documentation
}
```

## Access Patterns

CGD Toolkit modules support three deployment patterns:

### **Pattern 1: Fully Public (Development)**

**Use Case:** Development, testing, proof-of-concept

```hcl
module "ddc" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc?ref=v1.2.0"

  application_subnets = var.public_subnets   # Applications in public subnets
  service_subnets    = var.public_subnets    # Services in public subnets

  load_balancer_config = {
    nlb = {
      internet_facing = true
      subnets        = var.public_subnets
    }
  }
}
```

### **Pattern 2: Fully Private (High Security)**

**Use Case:** High security, compliance, production

```hcl
module "ddc" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc?ref=v1.2.0"

  application_subnets = var.private_subnets  # Applications in private subnets
  service_subnets    = var.private_subnets   # Services in private subnets

  load_balancer_config = {
    nlb = {
      internet_facing = false              # Internal load balancer
      subnets        = var.private_subnets
    }
  }

  # Requires VPN, Direct Connect, or bastion for access
}
```

### **Pattern 3: Hybrid (Recommended)**

**Use Case:** Production with external access needs

```hcl
module "ddc" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc?ref=v1.2.0"

  application_subnets = var.private_subnets  # Applications secure
  service_subnets    = var.private_subnets   # Services secure

  load_balancer_config = {
    nlb = {
      internet_facing = true               # External access via load balancer
      subnets        = var.public_subnets
    }
  }

  security_groups = [aws_security_group.office_access.id]  # Restricted access
}
```

## Load Balancer Configuration

Modules use a standardized `load_balancer_config` variable:

### **Network Load Balancer (NLB) - Always Available**

```hcl
load_balancer_config = {
  nlb = {
    enabled         = true                 # Required for most modules
    internet_facing = true                 # true = public, false = internal
    subnets        = var.public_subnets   # Where to place the NLB
    name_suffix    = "game-clients"        # Optional naming
  }
}
```

### **Application Load Balancer (ALB) - Module-Specific**

```hcl
# Only supported by modules with multiple web services (e.g., Perforce)
load_balancer_config = {
  nlb = {
    internet_facing = false
    subnets        = var.private_subnets
  }
  alb = {
    enabled         = true                 # Module must support ALB
    internet_facing = true
    subnets        = var.public_subnets
    enable_waf     = true                  # Web Application Firewall
  }
}
```

**Important:** All subnet variables are user-defined:

```hcl
# Your root module defines subnets
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }

# Or use direct resource references
subnets = aws_subnet.public[*].id
```

## Multi-Region Deployment

**⚠️ Important:** Multi-region deployment within a single Terraform state is only recommended for workloads that are **inherently benefited by multi-region architecture**. For example, Unreal Cloud DDC is designed as a distributed cache where multi-region deployment provides substantial performance benefits for geographically distributed teams.

**When to use shared-state multi-region:**

- **Distributed caching systems** (like DDC) where cross-region replication improves performance
- **Global data synchronization** where regions need to coordinate
- **Workloads designed for multi-region** as a core architectural pattern

**When to use separate deployments per region:**

- **Most applications** that don't require cross-region coordination
- **Independent regional services** (separate Jenkins, separate Perforce instances)
- **Disaster recovery scenarios** where regions are meant to be isolated

With AWS Provider v6, multi-region is simplified:

```hcl
# AWS Provider v6 - No provider aliases needed for AWS resources
module "ddc_us_east_1" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc?ref=v1.2.0"

  region = "us-east-1"  # Automatic region inheritance
  application_subnets = var.private_subnets_us_east_1

  load_balancer_config = {
    nlb = {
      internet_facing = true
      subnets        = var.public_subnets_us_east_1
    }
  }

  # Non-enhanced providers still require explicit aliases
  providers = {
    kubernetes = kubernetes.us_east_1
    helm       = helm.us_east_1
  }
}

module "ddc_us_west_2" {
  source = "git::https://github.com/aws-games/cloud-game-development-toolkit.git//modules/unreal/unreal-cloud-ddc?ref=v1.2.0"

  region = "us-west-2"  # Automatic region inheritance
  application_subnets = var.private_subnets_us_west_2

  load_balancer_config = {
    nlb = {
      internet_facing = true
      subnets        = var.public_subnets_us_west_2
    }
  }

  # Non-enhanced providers still require explicit aliases
  providers = {
    kubernetes = kubernetes.us_west_2
    helm       = helm.us_west_2
  }
}

# Provider aliases required for non-enhanced providers
provider "kubernetes" {
  alias = "us_east_1"
  # Configuration for us-east-1 cluster
}

provider "kubernetes" {
  alias = "us_west_2"
  # Configuration for us-west-2 cluster
}

provider "helm" {
  alias = "us_east_1"
  kubernetes {
    # Reference us-east-1 cluster
  }
}

provider "helm" {
  alias = "us_west_2"
  kubernetes {
    # Reference us-west-2 cluster
  }
}
```

**Important:** While AWS Provider v6 supports [enhanced region support](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-6-upgrade), other providers (Kubernetes, Helm, kubectl) still require [explicit provider aliases](https://developer.hashicorp.com/terraform/language/providers/configuration#multiple-provider-configurations) for multi-region deployments.

## Security Best Practices

### **Network Security**

- **Private-first**: Deploy applications in private subnets
- **Restricted access**: Use security groups, never `0.0.0.0/0` for ingress
- **Load balancer isolation**: Separate load balancer and application subnets

### **Access Control**

```hcl
# Create restricted security groups
resource "aws_security_group" "office_access" {
  name_prefix = "office-access"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "office_https" {
  security_group_id = aws_security_group.office_access.id
  description       = "HTTPS from office network"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4        = "203.0.113.0/24"  # Your office CIDR
}

# Use in module configuration
module "service" {
  security_groups = [aws_security_group.office_access.id]
}
```

## Contributing

For detailed information on contributing new modules or enhancing existing ones:

- **[Module Design Standards](./DESIGN_STANDARDS.md)** - Technical implementation guidelines for module contributors
- **[Contributing Guide](../CONTRIBUTING.md)** - General contribution process and requirements

**Quick Start for Contributors:**

1. Review existing module patterns and architecture
2. Follow the standardized variable naming and structure
3. Implement comprehensive tests and examples
4. Ensure security best practices are followed

## Module Architecture

CGD Toolkit modules follow a standardized structure:

```text
modules/service-name/
├── main.tf              # Parent module orchestration
├── variables.tf         # Input variables with validation
├── outputs.tf           # Module outputs
├── versions.tf          # Terraform and provider version constraints
├── README.md            # Module documentation
├── modules/             # Submodules for complex components
│   ├── infra/          # Infrastructure submodule (AWS resources)
│   └── services/       # Services submodule (Kubernetes/Helm)
├── tests/              # Terraform tests
│   ├── setup/          # Shared test configuration
│   └── *.tftest.hcl    # Unit and integration tests
└── examples/           # Working examples
    ├── single-region-basic/
    └── multi-region-basic/
```

### **Key Components**

- **Parent module**: Orchestrates submodules and provides user interface
- **Submodules**: Separate AWS resources (`infra/`) from Kubernetes resources (`services/`)
- **Examples**: Complete, deployable configurations showing usage patterns
- **Tests**: Automated validation of module functionality

## Troubleshooting

### **Common Issues**

#### Provider Configuration Errors

```bash
# Error: Invalid provider configuration
# Solution: Ensure AWS Provider v6+ for enhanced region support
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}
```

#### Subnet Configuration

```bash
# Error: Load balancer subnets must be provided
# Solution: Specify subnets in load_balancer_config
load_balancer_config = {
  nlb = {
    subnets = var.public_subnets  # Must provide subnet IDs
  }
}
```

#### Security Group Access

```bash
# Error: Cannot access service
# Solution: Check security group rules and CIDR blocks
security_groups = [aws_security_group.office_access.id]
```

### **Getting Help**

- **Module Documentation**: Each module has detailed README with examples
- **GitHub Issues**: [Report bugs or request features](https://github.com/aws-games/cloud-game-development-toolkit/issues)
- **Discussions**: [Ask questions](https://github.com/aws-games/cloud-game-development-toolkit/discussions)

## Next Steps

1. **Choose your access pattern** (public, private, or hybrid)
2. **Review module-specific documentation** for detailed configuration options
3. **Start with examples** to understand usage patterns
4. **Deploy in development** environment first
5. **Scale to production** with appropriate security controls
