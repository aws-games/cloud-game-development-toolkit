<!-- ---
title: Modules
description: Terraform modules for game development on AWS
---

# Modules

## Introduction

A module is an automated deployment of a game development workload (i.e. Jenkins, P4 Server, Unreal Horde) that is implemented as a Terraform module. They are designed to provide flexibility and customization via input variables with defaults based on typical deployment architectures. They are designed to be depended on from other modules (including your own root module), easily integrate with each other, and provide relevant outputs to simplify permissions, networking, and access. Some of the modules have pre-requisites that will be outlined in their respective documentation.

> Note: While the project focuses on Terraform modules today, this project may expand to provide options for implementations built in other IaC tools such as AWS CDK in the future.

!!! info
    **Don't see a module listed?** Create a [feature request](https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE) for a new module. If you'd like to contribute new modules to the project, see the [general docs on contributing](../../CONTRIBUTING.md), as well as the module specific contribution docs below.

| Module | Description |
| :--------------------------------------------------------------- | :- |
| [:simple-perforce: __Perforce__](../../modules/perforce/README.md)              | This module allows for deployment of Perforce resources on AWS. These are currently P4 Server (formerly Helix Core), P4Auth (formerly Helix Authentication Service), and P4 Code Review (formerly Helix Swarm). |
| [:simple-unrealengine: __Unreal Horde__](../../modules/unreal/horde/README.md)         | This module allows for deployment of Unreal Horde on AWS. |
| [:simple-unrealengine: __Unreal Cloud DDC__](../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra/README.md)              | This module allows for deployment of Unreal Cloud DDC (Derived Data Cache) on AWS. |
| [:simple-teamcity: __TeamCity__](../../modules/teamcity/README.md) | This module allows for deployment of TeamCity resources on AWS. |
[:simple-jenkins: __Jenkins__](../../modules/jenkins/README.md)              | This module allows for deployment of Jenkins on AWS.

## How to include these modules

We've found that including the **CGD Toolkit** repository as a git submodule in your own infrastructure repository is a good way of depending on the modules within an (existing) Terraform root module. Forking the **CGD Toolkit** and submoduling your fork may be a good approach if you intend to make changes to any modules. We recommend starting with the [Terraform module documentation](https://developer.hashicorp.com/terraform/language/modules) for a crash course in the way the **CGD Toolkit** is designed. Note how you can use the [module source argument](https://developer.hashicorp.com/terraform/language/modules/sources) to declare modules that use the **CGD Toolkit**'s module source code.

## Contribution

Please follow these guidelines when developing a new module. These are also outlined in the pull-request template for Module additions.

### 1. Provider Configurations

A module should *not* define its own provider configuration. Required provider versions should be outlined in a `required_versions` block inside of a `terraform` block:

```terraform
terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.30.0"
        }
        #...additional required providers
    }
}
```

### 2. Dependency Inversion

It is fine if your module needs to declare significant networking or compute resources to run - the *Cloud Game Development Toolkit* is intended to be highly opinionated. At the same time, we require that modules support a significant level of dependency injection through variables to support diverse use cases. This is a simple consideration that is easier to incorporate from the beginning of module development rather than retroactively.

For example, the [Jenkins module](../../modules/jenkins/README.md) can provision its own [Elastic Container Service](https://aws.amazon.com/ecs/) cluster, or it can deploy the Jenkins service onto an existing cluster passed via the `cluster_name` variable.

### 3. Assumptions and Guarantees

If your module requires certain input formats in order to function Terraform refers to these as "assumptions."

If your module provides certain outputs in a consistent format that other configurations should be able to rely on Terraform calls these "guarantees."

We recommend outlining your module's assumptions and guarantees prior to implementation by using Terraform [custom conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions). These can be used to validate input variables, data blocks, resource attributes, and much more. They are incredibly powerful.

### 4. Naming Conventions and Tagging
A module should provide a method for easily tagging the resources that it creates, while following a common naming convention. Currently the modules achieve this with a `project_prefix` variable that defaults to `cgd` (for Cloud Game Development Toolkit). This `project_prefix` is prepended to the beginning of the names of the deployed resources. The names themselves should be descriptive enough, but generally brief. For longer naming, leverage `tags` for resources that support them, using the `Name` key.

Ensure that tags have default values, but can be overwritten by users. For tags that we want to ensure are always present on resources, we achieve by merging the. For example:
### locals.tf
```hcl
locals {
    tags = merge(
      {
        "environment" = var.environment
      },
      var.tags,
    )
}
```
### main.tf

```hcl
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-${var.p4_server_type}-${local.p4_server_az}"
  })
```
The tags themselves should at the minimum include:

- `RootModuleName` - The name of the root module (only relevant if the module is a submodule)

- `ModuleName` - The name of the module itself

- `ModuleSource` - The location where the module is hosted

For example:
```hcl
variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "ParentModuleName" = "terraform-aws-perforce"
    "ModuleName"     = "p4-server"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce"
  }
```

### 5. Tests
All modules ***must*** include tests. This is to ensure functionality of modules as net new modules are created, or new functionality is added to existing ones. We have standardized with [Terraform test](https://developer.hashicorp.com/terraform/language/tests). For an example test, see the [tests for the Perforce module](https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce/tests).

To learn how to get started with Terraform tests, see [this AWS blog](https://aws.amazon.com/blogs/devops/terraform-ci-cd-and-testing-on-aws-with-the-new-terraform-test-framework/), and [this Terraform documentation](https://developer.hashicorp.com/terraform/language/tests).

### 6. Third Party Software

The modules contained in the **CGD Toolkit** are designed to simplify infrastructure deployments of common game development workload. Naturally, modules may deploy third party applications - in these situations we require that deployments depend on existing licenses and distribution channels.

If your module relies on a container or image that is not distributed through the **CGD Toolkit** we require a disclaimer and the usage of end-user credentials passed as a variable to the module. *This repository is not to be used to redistribute software that may be subject to licensing or contractual agreements*.

If your module relies on a custom Amazon Machine Image (AMI) or container we ask that you provide a Packer template or Dockerfile in the `assets/` directory and include instructions to create the image prior to infrastructure deployment. -->
