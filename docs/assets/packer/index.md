---
title: Packer Templates
description: Packer Templates for game development on AWS
---

# Packer Templates

[Packer](https://www.packer.io/) is a tool for simplifying and automating Amazon Machine Image (AMI) creation with code. It enables developers to create identical images for multiple platforms. The Packer templates provided in the Cloud Game Development Toolkit can be used to provision EC2 instances with common development tools preinstalled.

!!! info
    **Don't see a Packer template that solves your needs?** Create a [feature request](https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE) for a new template or learn [how to contribute new assets to the project below](#Contribute new Assets to the Cloud Game Development Toolkit)

| Template | Description |
| :--------------------------------------------------------------- | :- |
| [:simple-linux: __Linux Build Agents__](./build-agents/linux.md) | Provision C++ compilation machines on Amazon Linux 2023 and Ubuntu machines on both x86 and ARM based architectures with useful tools like compiler caches such as [Octobuild](https://github.com/octobuild/octobuild) preinstalled.|
| [:material-microsoft-windows-classic: __Windows Build Agents__](./build-agents/windows.md) | Create Windows 2022 based instances capable of Unreal Engine compilation out of the box. |
| [:simple-perforce: __Perforce Helix Core__](../../assets/ansible-playbooks/ansible-playbooks.md)         | An Amazon Machine Image used for provisioning Helix Core on AWS. This AMI is required for deployment of the [Perforce Helix Core module](../../modules/perforce/helix-core/helix-core.md) |
