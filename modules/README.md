# Modules

## Introduction

A module is an automated deployment of a game development workload (i.e. Jenkins, P4 Server, Unreal Horde) that is implemented as a Terraform module. They are designed to provide flexibility and customization via input variables with defaults based on typical deployment architectures. They are designed to be depended on from other modules (including your own root module), easily integrate with each other, and provide relevant outputs to simplify permissions, networking, and access.

> Note: While the project focuses on Terraform modules today, this project may expand to provide options for implementations built in other IaC tools such as AWS CDK in the future.

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

**Don't see a module listed?** Create a [feature request](https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE) for a new module. If you'd like to contribute new modules to the project, see the [general docs on contributing](../../CONTRIBUTING.md).

| Module                                                                                        | Description                                                                                                                                                                                                     | Status             |
| :-------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------- |
| [:simple-perforce: **Perforce**](../../modules/perforce/README.md)                            | This module allows for deployment of Perforce resources on AWS. These are currently P4 Server (formerly Helix Core), P4Auth (formerly Helix Authentication Service), and P4 Code Review (formerly Helix Swarm). | ✅ External Access |
| [:simple-unrealengine: **Unreal Horde**](../../modules/unreal/horde/README.md)                | This module allows for deployment of Unreal Horde on AWS.                                                                                                                                                       | ✅ External Access |
| [:simple-unrealengine: **Unreal Cloud DDC**](../../modules/unreal/unreal-cloud-ddc/README.md) | This module allows for deployment of Unreal Cloud DDC (Derived Data Cache) on AWS.                                                                                                                              | ✅ External Access |
| [:simple-jenkins: **Jenkins**](../../modules/jenkins/README.md)                               | This module allows for deployment of Jenkins on AWS.                                                                                                                                                            | ✅ External Access |
| [:simple-teamcity: **TeamCity**](../../modules/teamcity/README.md)                            | This module allows for deployment of TeamCity resources on AWS.                                                                                                                                                 | ✅ External Access |
| 🖥️ **VDI (Virtual Desktop Interface)**                                                        | Virtual desktop infrastructure for game development teams.                                                                                                                                                      | 🔜 Coming Soon     |
| **Monitoring**                                                                                | Pending development - will provide unified monitoring across all CGD services.                                                                                                                                  | 🚧 Future          |

**Note**: Current modules support external access with secured multi-layer security. Internal access patterns are planned for future releases.

## Contributing

For detailed information on contributing new modules or enhancing existing ones, see the [general docs on contributing](../../CONTRIBUTING.md).

**Module Structure Standards**: The parent module with submodules pattern described in the Module Architecture section is our standard approach for complex services with multiple components.

# Modules

## Introduction

These modules simplify the deployment of common game development workloads on AWS. Some have pre-requisites that will be outlined in their respective documentation. They are designed to be depended on from other modules (including your own root module), easily integrate with each other, and provide relevant outputs to simplify permissions, networking, and access.

## How to include these modules

We've found that including the **CGD Toolkit** repository as a git submodule in your own infrastructure repository is a good way of depending on the modules within an (existing) Terraform root module. Forking the **CGD Toolkit** and submoduling your fork may be a good approach if you intend to make changes to any modules. We recommend starting with the [Terraform module documentation](https://developer.hashicorp.com/terraform/language/modules) for a crash course in the way the **CGD Toolkit** is designed. Note how you can use the [module source argument](https://developer.hashicorp.com/terraform/language/modules/sources) to declare modules that use the **CGD Toolkit**'s module source code.

## Contribution

Please follow the guidelines outlines in the [module contribution guide]() guidelines when developing a new module. These are also outlined in the pull-request template for Module additions.
