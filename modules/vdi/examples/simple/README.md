# Simple VDI Example

This example demonstrates how to use the VDI module to create a Virtual Desktop Infrastructure instance on AWS.

## What This Example Creates

- A Windows Server 2025-based VDI instance using a custom AMI
- Security group with RDP and NICE DCV access
- IAM role and instance profile for AWS Systems Manager integration
- EBS volumes with encryption enabled
- Launch template for consistent deployments

## Prerequisites

1. **Custom AMI**: Ensure you have built the Windows Server 2025 AMI using the Packer template located at `assets/packer/virtual-workstations/windows/windows-server-2025.pkr.hcl`

2. **VPC and Subnet**: Update the `vpc_id` and `subnet_id` values in `main.tf` with your actual VPC and subnet IDs

3. **Key Pair**: (Optional) Create an EC2 key pair if you want to use an existing key instead of letting the module auto-generate one

4. **AWS Credentials**: Ensure your AWS credentials are configured (via AWS CLI, environment variables, or IAM roles)

## Usage

1. Clone this repository and navigate to this example directory:
   ```bash
   cd modules/vdi/examples/simple
   ```

2. Update the configuration in `main.tf`:
   - Replace `vpc-12345678` with your actual VPC ID
   - Replace `subnet-12345678` with your actual subnet ID
   - (Optional) Uncomment the `key_pair_name` line and replace with your actual key pair name if you're not using auto-generated keys
   - Adjust CIDR blocks for security group rules as needed

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Review the planned changes:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

6. When you're done, clean up the resources:
   ```bash
   terraform destroy
   ```

## Configuration Options

### Instance Type
The example uses `g4dn.2xlarge` which provides GPU capabilities suitable for graphics-intensive workloads. You can change this to other instance types based on your needs:
- `t3.large` - General purpose, cost-effective
- `m5.xlarge` - Balanced compute, memory, and networking
- `g4dn.xlarge` - GPU-enabled for graphics workloads
- `g4dn.4xlarge` - Higher performance GPU instance

### Storage Configuration
The example includes:
- Root volume: 512 GB GP3 with 4000 IOPS and 250 MB/s throughput
- Additional file storage volume: 1000 GB GP3 volume

### Security
- RDP access is restricted to private networks (10.0.0.0/8)
- The instance is deployed without a public IP by default
- EBS encryption is enabled for all volumes

## Accessing the VDI Instance

Once deployed, you can access the VDI instance via:

1. **RDP**: Use Remote Desktop Protocol to connect to the instance's private IP
2. **AWS Systems Manager Session Manager**: Connect through the AWS console without needing direct network access
3. **VPN/Bastion Host**: If deployed in a private subnet, use a VPN or bastion host for access

## Outputs

After deployment, the following information will be available:

- `vdi_instance_id`: The EC2 instance ID
- `vdi_private_ip`: The private IP address of the instance
- `vdi_public_ip`: The public IP address (if assigned)
- `ami_used`: Information about the AMI used
- `security_group_id`: The security group ID

## Cost Considerations

- `g4dn.2xlarge` instances can be expensive. Consider using smaller instance types for development/testing
- GP3 volumes with high IOPS/throughput settings increase costs
- Consider using Spot instances for non-production workloads to reduce costs

## Troubleshooting

### AMI Not Found
If you get an error about the AMI not being found:
1. Ensure the Packer build completed successfully
2. Check that the AMI is in the same AWS region
3. Verify the `ami_prefix` variable matches your AMI naming convention

### Network Connectivity Issues
If you can't connect to the instance:
1. Check security group rules
2. Verify the instance is in the correct subnet
3. Ensure your network can reach the instance's IP address
4. Check that the Windows firewall allows RDP connections

### Instance Launch Failures
If the instance fails to launch:
1. Check the instance type is available in your region/AZ
2. Verify you have sufficient EC2 limits
3. Check the subnet has available IP addresses
4. Review CloudTrail logs for detailed error messages
