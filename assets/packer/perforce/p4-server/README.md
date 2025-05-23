# P4 Server Packer Template

This Packer template creates an Amazon Machine Image for installing and configuring P4 Server on Linux. It supports both `x86` and `ARM` architectures.

The `p4_configure.sh` script contains the majority of P4 Server setup. It performs the following operations:

1. **Pre-Flight Checks**: Ensures the script is run with root privileges.
2. **Environment Setup**: Defines paths and necessary constants for the installation.
3. **SELinux Handling**: Checks if SELinux is enabled and installs required packages.
4. **User and Group Verification**: Ensures the 'perforce' user and group exist.
5. **Directory Creation and Ownership**: Ensures necessary directories exist and have correct ownership.
6. **P4 Binaries and SDP Installation**: Downloads and extracts SDP, checks for P4 binaries, and downloads them if missing.
7. **Systemd Service Configuration**: Sets up a systemd service for the p4d server.
8. **SSL Configuration**: Updates SSL certificate configuration with the EC2 instance DNS name.
9. **SELinux Context Management**: Updates SELinux context for p4d.
10. **Crontab Initialization**: Sets up crontab for the 'perforce' user.
11. **SDP Verification**: Runs a script to verify the SDP installation.
12. **P4Auth Extension**: Installs the [P4Auth Extension](https://github.com/perforce/helix-authentication-extension) and validates successful communication with P4Auth.


## How to Use

Building this AMI is as easy as running (x86 example):

``` bash
packer init ./assets/packer/perforce/p4-server/perforce_x86.pkr.hcl
```
``` bash
packer validate ./assets/packer/perforce/p4-server/perforce_x86.pkr.hcl
```
``` bash
packer build ./assets/packer/perforce/p4-server/perforce_x86.pkr.hcl
```

Packer will attempt to leverage the default VPC available in the AWS account and Region specified by your CLI credentials. It will provision an instance in a public subnet and communicate with that instance over the public internet. If a default VPC is not available or otherwise provided, the above command will fail. This Packer template can take a number of variables as specified in `example.pkrvars.hcl`. Variables can be passed individually through the `-var` command line flag or through a configuration file with the `-var-file` command line flag.

An instance that is provisioned with this AMI will not automatically deploy a P4 Server. Instead, the required installation and configuration scripts are loaded onto this AMI by Packer, and then invoked at boot through EC2 user data. The P4 Server module does this through Terraform, but you can also manually provision an instance off of this AMI and specify the user data yourself:

``` bash
#!/bin/bash
/home/ec2-user/cloud-game-development-toolkit/p4_configure.sh \
   <volume label for hxdepot> \
   <volume label for hxmetadata> \
   <volume label for hxlogs> \
   <p4d server type> \
   <super user username ARN from AWS Secrets Manager> \
   <super user password ARN from AWS Secrets Manager> \
   <fully qualified domain name of P4 Server> \
   <URL for P4Auth>
```

As you can see, there are quite a few parameters that need to be passed to the `p4_configure.sh` script. We recommend using the [Perforce module](../../../../modules/perforce/README.md) for this reason.

## Important Notes

- This script is designed for a specific use-case and might require modifications for different environments or requirements.
- Ensure you have a backup of your system before running the script, as it makes significant changes to users, groups, and services.
- The script assumes an internet connection for downloading packages and binaries.
