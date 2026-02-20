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
   --p4d_type p4d_master \
   --hx_depots /dev/sdf \
   --hx_metadata /dev/sdg \
   --hx_logs /dev/sdh \
   --super_password <AWS Secrets Manager secret ID for service account password> \
   --admin_username <AWS Secrets Manager secret ID for admin username> \
   --admin_password <AWS Secrets Manager secret ID for admin password> \
   --fqdn perforce.example.com \
   --auth https://auth.perforce.example.com
```

### Script Options

| Option | Description |
|--------|-------------|
| `--p4d_type` | P4 Server type: `p4d_master`, `p4d_replica`, or `p4d_edge` |
| `--hx_depots` | Path/device for P4 Server depots volume |
| `--hx_metadata` | Path/device for P4 Server metadata volume |
| `--hx_logs` | Path/device for P4 Server logs volume |
| `--super_password` | AWS Secrets Manager secret ID for service account (super) password |
| `--admin_username` | AWS Secrets Manager secret ID for admin account username |
| `--admin_password` | AWS Secrets Manager secret ID for admin account password |
| `--fqdn` | Fully Qualified Domain Name for the P4 Server |
| `--auth` | P4Auth URL (optional) |
| `--case_sensitive` | Case sensitivity: `0` (insensitive) or `1` (sensitive, default) |
| `--unicode` | Enable Unicode mode: `true` or `false` |
| `--selinux` | Update SELinux labels: `true` or `false` |
| `--plaintext` | Disable SSL: `true` or `false` |
| `--fsxn_password` | AWS Secrets Manager secret ID for FSxN password |
| `--fsxn_svm_name` | FSxN Storage Virtual Machine name |
| `--fsxn_management_ip` | FSxN management IP address |

### User Configuration

The script creates two Perforce users:

1. **Service Account (`super`)**: Always created with username "super". Used internally by P4 Code Review (Helix Swarm) and other tooling. Password provided via `--super_password`.

2. **Admin Account**: Created with the username provided via `--admin_username`. This is the account for human administrators. Password provided via `--admin_password`.

Both users have full super privileges and are added to the `unlimited_timeout` group.

We recommend using the [Perforce module](../../../../modules/perforce/README.md) to manage these configurations through Terraform.

## Important Notes

- This script is designed for a specific use-case and might require modifications for different environments or requirements.
- Ensure you have a backup of your system before running the script, as it makes significant changes to users, groups, and services.
- The script assumes an internet connection for downloading packages and binaries.
