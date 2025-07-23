---
title: Packer Templates
description: Packer Templates for game development on AWS
---

# Packer Templates

[Packer](https://www.packer.io/) is a tool for simplifying and automating Amazon Machine Image (AMI) creation with code. It enables developers to create identical images for multiple platforms. The Packer templates provided in the Cloud Game Development Toolkit can be used to provision EC2 instances with common development tools preinstalled.

!!! info
    **Don't see a Packer template that solves your needs?** Create a [feature request](https://github.com/aws-games/cloud-game-development-toolkit/issues/new?assignees=&labels=feature-request&projects=&template=feature_request.yml&title=Feature+request%3A+TITLE) for a new template or learn [how to contribute new assets to the project](../../../CONTRIBUTING.md)

| Template | Description |
| :--------------------------------------------------------------- | :- |
| [:simple-linux: __Linux Build Agents__](../../../assets/packer/build-agents/linux/README.md) | Provision C++ compilation machines on Amazon Linux 2023 and Ubuntu machines on both x86 and ARM based architectures with useful tools like compiler caches such as [Octobuild](https://github.com/octobuild/octobuild) preinstalled.|
| [:material-microsoft-windows-classic: __Windows Build Agents__](../../../assets/packer/build-agents/windows/README.md) | Create Windows 2022 based instances capable of Unreal Engine compilation out of the box. |
| [:simple-perforce: __P4 Server (formerly Helix Core)__](../../../assets/packer/perforce/p4-server/README.md)         | An Amazon Machine Image used for provisioning P4 Server on AWS. This AMI is required for deployment of the [Perforce module](../../../modules/perforce/README.md) |
| [:material-desktop-classic: __Virtual Workstations (Windows)__](../../../assets/packer/virtual-workstations/windows/README.md) | AWS Virtual Workstation AMI for Unreal Engine development |
