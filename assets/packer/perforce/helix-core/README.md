### Perforce Helix Core Packer Template

#### Overview

This Packer template automates the deployment and configuration of a Helix Core Server (P4D) on a Linux environment, specifically tailored for use with SELinux and systemd. It performs various tasks such as checking and setting up the necessary user and group, handling SELinux context, installing and configuring Perforce Software's Server Deployment Package (SDP), and setting up the Helix Core service with systemd.

Steps in the Packer template automation include: 

1. **Pre-Flight Checks**: Ensures the script is run with root privileges.
2. **Environment Setup**: Defines paths and necessary constants for the installation.
3. **SELinux Handling**: Checks if SELinux is enabled and installs required packages.
4. **User and Group Verification**: Ensures the 'perforce' user and group exist.
5. **Directory Creation and Ownership**: Ensures necessary directories exist and have correct ownership.
6. **Helix Binaries and SDP Installation**: Downloads and extracts SDP, checks for Helix binaries, and downloads them if missing.
7. **Systemd Service Configuration**: Sets up a systemd service for the p4d server.
8. **SSL Configuration**: Updates SSL certificate configuration with the EC2 instance DNS name.
9. **SELinux Context Management**: Updates SELinux context for p4d.
10. **Crontab Initialization**: Sets up crontab for the 'perforce' user.
11. **SDP Verification**: Runs a script to verify the SDP installation.

#### Prerequisites

- A Linux system with DNF package manager (e.g., Fedora, RHEL, CentOS).
- Root access to the system.
- SELinux in Enforcing or Permissive mode (optional but recommended).
- Access to the internet for downloading necessary packages and binaries.

#### How to Use

1. **Download the Script**: Clone or download this repository to your system.
2. **Provide Execution Permission**: Give execute permission to the script using `chmod +x <script_name>.sh`.
3. **Run the Script**: Execute the script as root:

   ```
   sudo ./<script_name>.sh
   ```

4. **Follow the On-Screen Instructions**: The script is mostly automated, but monitor the output for any errors or required manual inputs.

#### Important Notes

- This script is designed for a specific use-case and might require modifications for different environments or requirements.
- Ensure you have a backup of your system before running the script, as it makes significant changes to users, groups, and services.
- The script assumes an internet connection for downloading packages and binaries.
