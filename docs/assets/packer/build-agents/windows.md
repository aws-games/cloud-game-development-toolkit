---
title: Unreal Engine Windows Build Agents
description: Packer Templates for Unreal Engine Windows Build Agents on AWS
---

# Packer Templates for Unreal Engine Windows Build Agents

The following template builds a Windows based AMI capable of Unreal Engine 5.4 compilation jobs. Please customize it to your needs.

## Usage

This Amazon Machine Image is provisioned using the Windows Server 2022 base operating system. It installs all required tooling for Unreal Engine 5 compilation by default. Please consult [the release notes for Unreal Engine 5.4](https://dev.epicgames.com/documentation/en-us/unreal-engine/unreal-engine-5.4-release-notes#platformsdkupgrades) for details on what tools are used for compiling this version of the engine.

The only required variable for building this Amazon Machine Image is a public SSH key.

``` bash
packer build windows.pkr.hcl \
    -var "public_key=<include public ssh key here>"
```

???+ Note
    The above command assumes you are running `packer` from the `/assets/packer/build-agents/windows` directory.

You will then want to upload the private SSH key to AWS Secrets Manager so that the Jenkins orchestration service can use it to connect to this build agent.

``` bash
aws secretsmanager create-secret \
    --name JenkinsPrivateSSHKey \
    --description "Private SSH key for Jenkins build agent access." \
    --secret-string "<insert private SSH key here>" \
    --tags 'Key=jenkins:credentials:type,Value=sshUserPrivateKey' 'Key=jenkins:credentials:username,Value=jenkins'
```

Take note of the output of this CLI command. You will need the ARN later.

Currently this AMI is designed to work with our Jenkins module. This is why it creates a `jenkins` user and the associated SSH username for the key you upload is that same `jenkins` user. [Expanded customization of this AMI is currently on the Cloud Game Development Toolkit roadmap.](https://github.com/orgs/aws-games/projects/1/views/1?pane=issue&itemId=74515666)

## Installed Tooling

- Chocolatey package manager
- OpenJDK used by Jenkins agents
- Git
- OpenSSH
- Python3
    - Botocore
    - Boto3
- Client for Network File System (NFS)
- Windows Development Kit and Debugging Tools
- Visual Studio 2022 Build Tools
    - VCTools Workload; Include Recommended
    - ManagedDesktopBuild Tools; Include Recommended
    - MSVC v143 - VS 2022 C++ x64/x86 build tools
    - Microsoft.Net.Component.4.6.2TargetingPack

Consult the [Visual Studio Build Tools component directory](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022) for details.
