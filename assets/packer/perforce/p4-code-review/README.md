# P4 Code Review Packer Template

This Packer template creates an Amazon Machine Image (AMI) for P4 Code Review (Helix Swarm) on Ubuntu 24.04 LTS. The AMI includes all necessary software pre-installed, with runtime configuration handled automatically during instance launch.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [What Gets Installed](#what-gets-installed)
- [Building the AMI](#building-the-ami)
- [Finding Your AMI](#finding-your-ami)
- [Next Steps](#next-steps)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before building the AMI, ensure you have:

1. **AWS CLI** configured with valid credentials:

   ```bash
   aws configure
   # Verify access
   aws sts get-caller-identity
   ```

2. **Packer** installed (version >= 1.8.0):

   ```bash
   packer version
   ```

   If not installed, download from <https://www.packer.io/downloads>

3. **VPC Access**:
   - Default VPC in your region (Default behaviour)
   - OR custom VPC with a public subnet (Can be configured by passing the VPC id through the `vpc_id` variable)

4. **IAM Permissions**: Your AWS credentials need permissions to:
   - Launch EC2 instances
   - Create AMIs
   - Create/delete security groups
   - Create/delete key pairs

## Quick Start

From the **repository root**, run:

```bash
# 1. Navigate to Packer template directory
cd assets/packer/perforce/p4-code-review

# 2. Initialize Packer (downloads required plugins)
packer init p4_code_review_x86.pkr.hcl

# 3. Validate the template
packer validate p4_code_review_x86.pkr.hcl

# 4. Build the AMI (takes ~10-15 minutes)
packer build p4_code_review_x86.pkr.hcl
```

At the end of the build, Packer will output the AMI ID:

```text
==> amazon-ebs.ubuntu2404: AMI: ami-0abc123def456789
```

**Save this AMI ID** - you'll need it for Terraform deployment.

## What Gets Installed

The AMI includes a complete P4 Code Review installation:

### Software Components

1. **Perforce Repository**: Official Perforce package repository (Ubuntu jammy/22.04 compatible)
2. **PHP 8.x**: PHP runtime with all required extensions:
     1. Core: curl, mbstring, xml, intl, ldap, bcmath
     2. Database: mysql
     3. Graphics: gd
     4. Archive: zip
     5. PECL: igbinary, msgpack, redis
3. **Helix Swarm**: Native DEB installation via `helix-swarm` package
4. **Apache2**: Web server with mod_php and required modules (rewrite, proxy, proxy_fcgi)
5. **PHP-FPM**: FastCGI Process Manager for PHP
6. **helix-swarm-optional** (optional, installed by default): LibreOffice for document preview (.docx, .xlsx, .pptx) and ImageMagick for image preview (.png, .jpg, .tiff, etc.) (~500MB)
7. **AWS CLI v2**: Required for Secrets Manager access and EBS volume operations at runtime
8. **Configuration Script**: `/home/ubuntu/swarm_scripts/swarm_instance_init.sh` for runtime setup (see Runtime Configuration Details below)

### System Configuration

- **AppArmor**: Ubuntu's security module (less restrictive by default for `/opt`)
- **Services**: Apache2 and PHP-FPM enabled for automatic startup
- **User**: `swarm` system user created with proper permissions
- **Directories**: `/opt/perforce/swarm` prepared with correct ownership

### What's NOT Configured Yet

The following are configured at **deployment** when you launch an instance:

- P4 Server connection details
- P4 user credentials (fetched from AWS Secrets Manager)
- Redis cache connection
- External hostname/URL
- SSO settings
- EBS volume mounting for persistent data
- Queue worker configuration (cron job and endpoint)
- File permissions for worker processes
- P4 Server extension installation (Swarm triggers)

### Runtime Configuration Details

When an EC2 instance launches, the user-data script performs the following steps:

1. **EBS Volume Attachment**: Finds and attaches the persistent data volume by tags
2. **Filesystem Setup**: Creates ext4 filesystem (first launch) or mounts existing one
3. **Swarm Configuration**: Executes `/home/ubuntu/swarm_scripts/swarm_instance_init.sh` which:
   - Retrieves P4 credentials from AWS Secrets Manager
   - Runs Perforce's official `configure-swarm.sh` to:
     - Connect to P4 Server and validate credentials
     - Install Swarm extension on P4 Server (enables event triggers)
     - Create initial configuration file
     - Set up Apache VirtualHost
     - Create cron job for queue workers
   - Configures file permissions for queue worker functionality
   - Updates configuration with Redis connection details
   - Configures queue workers to use localhost endpoint
   - Starts Apache and PHP-FPM services

**Queue Workers**: P4 Code Review requires background workers to process events, send notifications, and index files. These are spawned by a cron job (created by `configure-swarm.sh`) that runs every minute. The runtime configuration ensures workers have proper permissions and connect to the correct endpoint.

## Building the AMI

### Option 1: Using Default VPC (Recommended)

If your AWS region has a default VPC:

```bash
cd assets/packer/perforce/p4-code-review
packer init p4_code_review_x86.pkr.hcl
packer build p4_code_review_x86.pkr.hcl
```

### Option 2: Using Custom VPC

If you don't have a default VPC, specify your own:

```bash
packer build \
  -var="region=us-west-2" \
  -var="vpc_id=vpc-xxxxx" \
  -var="subnet_id=subnet-xxxxx" \
  -var="associate_public_ip_address=true" \
  -var="ssh_interface=public_ip" \
  p4_code_review_x86.pkr.hcl
```

**Requirements for custom VPC**:

- Subnet must be in a **public** subnet (has route to Internet Gateway)
- `associate_public_ip_address=true` if subnet doesn't auto-assign public IPs
- Security group allows outbound internet access (for package downloads)

### Option 3: Using Variables File

Create a `my-vars.pkrvars.hcl`:

```hcl
region                       = "us-west-2"
vpc_id                       = "vpc-xxxxx"
subnet_id                    = "subnet-xxxxx"
associate_public_ip_address  = true
ssh_interface                = "public_ip"
```

Then build:

```bash
packer build -var-file="my-vars.pkrvars.hcl" p4_code_review_x86.pkr.hcl
```

### Build Output

Successful build output looks like:

```text
==> amazon-ebs.ubuntu2404: Stopping the source instance...
==> amazon-ebs.ubuntu2404: Waiting for the instance to stop...
==> amazon-ebs.ubuntu2404: Creating AMI p4_code_review_ubuntu-20231209123456 from instance i-xxxxx
==> amazon-ebs.ubuntu2404: AMI: ami-0abc123def456789
==> amazon-ebs.ubuntu2404: Waiting for AMI to become ready...
==> amazon-ebs.ubuntu2404: Terminating the source AWS instance...
Build 'amazon-ebs.ubuntu2404' finished after 12 minutes 34 seconds.

==> Wait completed after 12 minutes 34 seconds

==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.ubuntu2404: AMIs were created:
us-west-2: ami-0abc123def456789
```

**Copy the AMI ID** (e.g., `ami-0abc123def456789`) - you'll need this for Terraform.

## Finding Your AMI

### List All P4 Code Review AMIs

```bash
aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=p4_code_review_ubuntu-*" \
  --query 'Images[*].[ImageId,Name,CreationDate]' \
  --output table
```

Output:

```text
+-----------------------------------------------------------------------+
|                         DescribeImages                                |
+----------------------+---------------------------------------+--------+
|  ami-0abc123def456   | p4_code_review_ubuntu-20231209    | 2023...|
|  ami-0def456abc789   | p4_code_review_ubuntu-20231208    | 2023...|
+----------------------+---------------------------------------+--------+
```

### Get the Latest AMI

```bash
aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=p4_code_review_ubuntu-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[ImageId,Name,CreationDate]' \
  --output table
```

### Get Details About a Specific AMI

```bash
aws ec2 describe-images --image-ids ami-0abc123def456789
```

## Next Steps

Now that you have an AMI, proceed to deploy P4 Code Review infrastructure:

1. **Read the [P4 Code Review Module Documentation](../../../../modules/perforce/modules/p4-code-review/README.md)**

2. **Follow the deployment guide** in the module README, which covers:
   - Creating AWS Secrets Manager secrets for P4 credentials
   - Writing Terraform configuration
   - Deploying the infrastructure
   - Accessing the P4 Code Review web console

## Troubleshooting

### "No default VPC available"

**Error**: Packer fails with "No default VPC for this user"

**Solution**: Use Option 2 or 3 above to specify your VPC and subnet:

```bash
packer build \
  -var="vpc_id=vpc-xxxxx" \
  -var="subnet_id=subnet-xxxxx" \
  p4_code_review_x86.pkr.hcl
```

### "Unable to connect to instance"

**Error**: Packer times out connecting to the instance

**Possible causes**:

1. Subnet is not public (no route to Internet Gateway)
2. Security group blocks SSH (port 22)
3. No public IP assigned to instance

**Solution**: Verify your subnet has:

```bash
# Check if subnet has route to IGW
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxxxx" \
  --query 'RouteTables[*].Routes[?GatewayId!=`local`]'
```

### "Package installation failed"

**Error**: APT/DEB errors during build

**Possible causes**:

1. No internet access from instance
2. Perforce repository temporarily unavailable
3. Package version conflicts

**Solution**:

- Check build instance has outbound internet access
- Try rebuilding (temporary outages resolve themselves)
- Review `/var/log/swarm_setup.log` on build instance

### "AMI already exists with that name"

**Error**: "AMI name 'p4_code_review_ubuntu-TIMESTAMP' already exists"

**This shouldn't happen** (timestamp should be unique), but if it does:

```bash
# List your AMIs
aws ec2 describe-images --owners self \
  --filters "Name=name,Values=p4_code_review_ubuntu-*"

# Deregister old AMI if no longer needed
aws ec2 deregister-image --image-id ami-xxxxx
```

### Build is slow

**Normal build time**: 10-15 minutes

**If taking longer**:

- Package downloads can be slow depending on region
- Perforce repository might be experiencing high load
- This is normal - be patient

### Need to debug the build?

**Enable debug mode to step through each provisioner**:

```bash
packer build -debug p4_code_review_x86.pkr.hcl
```

This will pause before each provisioner step, allowing you to:

- SSH into the build instance
- Inspect the current state
- Verify installation progress
- Press Enter to continue to the next step

**Enable detailed logging**:

```bash
PACKER_LOG=1 packer build p4_code_review_x86.pkr.hcl
```

## Additional Resources

- [Packer Documentation](https://www.packer.io/docs)
- [Perforce Helix Swarm Admin Guide](https://www.perforce.com/manuals/swarm/Content/Swarm/Home-swarm.html)
- [Ubuntu 24.04 LTS Documentation](https://ubuntu.com/server/docs)

## Questions or Issues?

If you encounter problems:

1. Check the troubleshooting section above
2. Review Packer logs with `PACKER_LOG=1`
3. Use `packer build -debug` to step through the build process
4. Verify AWS credentials and permissions
