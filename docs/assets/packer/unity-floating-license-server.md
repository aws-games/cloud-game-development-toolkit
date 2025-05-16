---
title: Unity Floating License Server Packer Template
description: Unity Floating License Server Packer Template for game development on AWS
---

# Unity Floating License Server Packer Template

This Packer template creates an Amazon Machine Image for installing a Unity License server on Linux. It supports both x86 and ARM architectures.

The `install_unzip.ubuntu.sh` script contains the dependencies required to extract the files from the Unity License Server zip that is provided by Unity.

To run this packer script you will have to provide a path Unity License Server zip so that the packer script can upload it to the instance. Just note that there will be additional configuration


## How to Use

Ensure your path_to_unity_license_server_zip is set to the relative path from the module. Once set, building this AMI is as easy as running (ARM example):

``` bash
packer build ./assets/packer/unity/unity-floating-license-server/ubuntu-jammy-22.04-arm64-unity-floating-license-server.pkr.hcl
```

Packer will attempt to leverage the default VPC available in the AWS account and Region specified by your CLI credentials. It will provision an instance in a public subnet and communicate with that instance over the public internet. If a default VPC is not provided the above command will fail. This Packer template can take a number of variables as specified in `example.pkrvars.hcl`. Variables can be passed individually through the `-var` command line flag or through a configuration file with the `-var-file` command line flag.

An instance that is provisioned with this AMI will not automatically deploy a Unity License Server. Instead, you will need to launch the ami with the Unity License Server module and run some commands via cli (the module will provide instructions on how to do this in ssm) to get the service up and running.
