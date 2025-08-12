# VDI Example with Managed Microsoft AD

This example demonstrates how to create a complete VDI environment with Managed Microsoft AD integration in a single `terraform apply`.

## Architecture

This example creates:
- **VPC** with public and private subnets
- **Managed Microsoft AD** directory
- **VDI instances** with automatic domain joining
- **AD users** created automatically
- **Complete networking** (NAT Gateway, Internet Gateway, Route Tables)

## Key Features

- **Single Apply**: No two-step process required
- **Automatic AD Integration**: Directory creation and domain joining handled automatically
- **User Management**: AD users created based on VDI configuration tags
- **Complete Infrastructure**: All networking and security components included

## Prerequisites

1. **Custom AMI**: Build the Windows Server 2025 AMI using the Packer template at `assets/packer/virtual-workstations/windows/windows-server-2025.pkr.hcl`

2. **AWS Credentials**: Ensure your AWS credentials include permissions for:
   - Directory Service operations
   - EC2 instance management
   - VPC and networking resources

## Usage

1. **Navigate to the example directory**:
   ```bash
   cd modules/vdi/examples
   ```

2. **Create terraform.tfvars file**:
# Example Terraform variables file for VDI deployment
# Copy this file to terraform.tfvars and update with your actual values

########################################
# REQUIRED VARIABLES
########################################

# Shared temporary password for all VDI users (stored in Secrets Manager)
# Users will be forced to change this on first login
admin_password = "TempPassword123!"

# Password for the Managed Microsoft AD administrator account (REQUIRED)
directory_admin_password = "YourSuperSecretPassword123!"

# Managed Microsoft AD domain name (REQUIRED)
directory_name = "corp.example.com"

########################################
# OPTIONAL VARIABLES
########################################

# Optional: Domain name for DNS record (creates vdi-johnsmith.example.com)
# domain_name = "example.com"

# Optional: Directory edition (Standard or Enterprise)
# directory_edition = "Standard"

# Optional: Whether to associate public IP addresses
# associate_public_ip_address = true

# Optional: VPC CIDR block
# vpc_cidr = "10.0.0.0/16"

# Optional: Project prefix for resource naming
# project_prefix = "cgd"

# Optional: Environment name
# environment = "dev"

3. **Initialize and apply**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Access your VDI instances**:
   - Use the outputs to get connection information
   - Connect via RDP or NICE DCV
   - Login with domain credentials: `CORP\username` + temporary password
   - Change password on first login

5. **Clean up when done**:
   ```bash
   terraform destroy
   ```

## Configuration

### VDI Users

The example creates two users by default:
- **JohnSmith**: Developer workstation with standard configuration
- **SarahJohnson**: Designer workstation with more powerful specs and additional storage

Each user configuration includes:
- Instance specifications (type, storage, networking)
- AD user information (name, email, role)
- Security settings (key pairs, passwords)

### Active Directory

The Managed Microsoft AD is configured with:
- Domain name from `directory_name` variable
- Standard edition (can be changed to Enterprise)
- Automatic DHCP options configuration
- Security groups with least-privilege access

### Networking

The VPC includes:
- Public subnets for VDI instances (with internet access)
- Private subnets for Managed AD (in different AZs)
- NAT Gateway for outbound internet access from private subnets
- Proper routing and security group configurations

## Outputs

After deployment, you'll get:
- VDI instance information (IDs, IPs, connection details)
- Directory information (ID, DNS servers)
- AD user information (usernames, login format)
- Connection instructions for NICE DCV and RDP

## Password Management

This example uses a **shared temporary password** approach:
1. All users start with the same temporary password (`admin_password`)
2. AD users are created automatically during deployment
3. Users must change password on first login
4. Each user then has their own secure password

## Cost Considerations

- **Instance Types**: `g4dn.2xlarge` and `g4dn.4xlarge` are GPU instances suitable for graphics work
- **Storage**: GP3 volumes with high IOPS can be expensive
- **NAT Gateway**: Incurs hourly charges and data processing fees
- **Managed AD**: Standard edition has monthly charges

## Troubleshooting

### Validation Errors
If you get validation errors, run:
```bash
terraform validate
```

### Directory Creation Issues
- Ensure private subnets are in different availability zones
- Check AWS service quotas for Directory Service

### Domain Join Failures
- Verify directory is in "Active" state
- Check security group rules allow AD traffic
- Review SSM association execution logs

### Connection Issues
- Verify security groups allow RDP (3389) and DCV (8443) traffic
- Check that instances have public IPs if accessing from internet
- Ensure Windows firewall allows connections

## Customization

You can customize this example by:
- Modifying user configurations in `main.tf`
- Adjusting VPC CIDR blocks and subnet configurations
- Changing instance types and storage configurations
- Adding additional users to the `vdi_config` map
- Modifying security group rules for your network requirements