---
template: index.html
title: Cloud Game Development Toolkit
hide: [navigation]
hero:
  title: Tools and best practices for deploying game development infrastructure on AWS
  subtitle: Get started with ready-to-use templates or use only what you need
  getting_started_button: Getting Started
  source_button: Source Code
features:
  - title: Assets
    #image: media/images/assets.png
    description: Foundational resources such as image templates, configurations scripts, and CI/CD pipeline definitions for game development.
  - title: Modules
    #image: media/images/modules.png
    description: Terraform Modules for deploying common game dev workloads with best-practices by default.
  - title: Samples
    #image: media/images/samples.png
    description: Opinionated ready-to-use implementations to address common use cases for expedited game studio setup and battle-tested scenarios from the community.
companies:
  title:
  list:
---

# Welcome to the Cloud Game Development Toolkit

!!! info
    **This project is under active development and community contributions are welcomed!**. If you would like to see something in this repository please create a <a href="https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE" target="_blank">feature request</a> in the Issues tab. If you'd like to contribute, raise a <a href="https://github.com/aws-games/cloud-game-development-toolkit/pulls/" target="_blank">pull request</a>. You'll find our contribution guidelines [here](./contributing.md).

The **Cloud Game Development Toolkit (a.k.a. CGD Toolkit)** is a collection of templates and configurations for deploying game development infrastructure and tools on AWS.

Below are key principles and goals driving project's focus:

- **This is a fork-first, open-source project**. We know that every game project is unique, so fork the repo, create your own branches for customization and sync as appropriate. If you build something that can benefit other game developers, feel free to share via PR, as we encourage contributions!
- **Meet game developers where they are**. We aim to minimize the introduction of new tools and technologies by building solutions that incorporate widely used software from across the game industry and popular among our game customers.
- **Solutions are built for AWS**. This project is focused on improving the game development experience on AWS and does not try to standardize solutions for deployment across many hosting platforms. In our experience, doing so is generally difficult, unecessary, and fraught with tradeoffs. If AWS is not your jam, you're welcome to fork and customize as needed (see above)!

## Getting Started

[Getting Started](./getting-started.md){ .md-button  }

## License

This project is licensed under the [MIT-0 License](https://github.com/aws-games/cloud-game-development-toolkit/blob/main/LICENSE).
