# Modules

## Introduction

These modules simplify the deployment of common game development workloads on AWS. Some have pre-requisites that will be outlined in their respective documentation. They are designed to be depended on from other modules (including your own root module), easily integrate with each other, and provide relevant outputs to simplify permissions, networking, and access.

## How to include these modules

We've found that including the **CGD Toolkit** repository as a git submodule in your own infrastructure repository is a good way of depending on the modules within an (existing) Terraform root module. Forking the **CGD Toolkit** and submoduling your fork may be a good approach if you intend to make changes to any modules. We recommend starting with the [Terraform module documentation](https://developer.hashicorp.com/terraform/language/modules) for a crash course in the way the **CGD Toolkit** is designed. Note how you can use the [module source argument](https://developer.hashicorp.com/terraform/language/modules/sources) to declare modules that use the **CGD Toolkit**'s module source code.

## Contribution

Please follow these guidelines when developing a new module. These are also outlined in the pull-request template for Module additions.

### 1. Provider Configurations

Modules should *not* define its own provider configurations. Required provider versions should be outlined in a `required_versions` block inside of a `terraform` block:

```terraform
terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = ">= 5.30.0"
        }
    }
}
```

### 2. Dependency Inversion

It is fine if your module needs to declare significant networking or compute resources to run - the *Cloud Game Development Toolkit* is intended to be highly opinionated. At the same time, we require that modules support a significant level of dependency injection through variables to support diverse use cases. This is a simple consideration that is easier to incorporate from the beginning of module development rather than retroactively.

For example, the [Jenkins module](./jenkins/jenkins.md) can provision its own [Elastic Container Service](https://aws.amazon.com/ecs/) cluster, or it can deploy the Jenkins service onto an existing cluster passed via the `cluster_name` variable.

### 3. Assumptions and Guarantees

If your module requires certain input formats in order to function Terraform refers to these as "assumptions."

If your module provides certain outputs in a consistent format that other configurations should be able to rely on Terraform calls these "guarantees."

We recommend outlining your module's assumptions and guarantees prior to implementation by using Terraform [custom conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions). These can be used to validate input variables, data blocks, resource attributes, and much more. They are incredibly powerful.

### 4. Third Party Software

The modules contained in the **CGD Toolkit** are designed to simplify infrastructure deployments of common game development workload. Naturally, modules may deploy third party applications - in these situations we require that deployments depend on existing licenses and distribution channels.

If your module relies on a container or image that is not distributed through the **CGD Toolkit** we require a disclaimer and the usage of end-user credentials passed as a variable to the module. *This repository is not to be used to redistribute software that may be subject to licensing or contractual agreements*.

If your module relies on a custom Amazon Machine Image (AMI) or container we ask that you provide a Packer template or Dockerfile in the `assets/` directory and include instructions to create the image prior to infrastructure deployment.
