# VDI Example with VPC Creation

This example demonstrates how to use the VDI module to create a Virtual Desktop Infrastructure instance on AWS with a new VPC containing public and private subnets.

## What This Example Creates

- A complete VPC infrastructure:
  - Public and private subnets across multiple availability zones
  - Internet Gateway for public subnet connectivity
  - NAT Gateway for private subnet outbound access
  - Appropriate route tables for network traffic
- A Windows Server 2025-based VDI instance in a private subnet
- Security group with RDP and NICE DCV access
- IAM role and instance profile for AWS Systems Manager integration
- EBS volumes with encryption enabled
- Launch template for consistent deployments

## Prerequisites

1. **Custom AMI**: Ensure you have built the Windows Server 2025 AMI using the Packer template located at `assets/packer/virtual-workstations/windows/windows-server-2025.pkr.hcl`

2. **Network Planning**: Review the CIDR blocks and availability zones in the example to ensure they're suitable for your environment

3. **AWS Credentials**: Ensure your AWS credentials are configured (via AWS CLI, environment variables, or IAM roles)

4. **AWS Limits**: Verify you have sufficient quotas for VPC resources (NAT Gateways, Elastic IPs, etc.)

## Usage

1. Clone this repository and navigate to this example directory:
   ```bash
   cd modules/vdi/examples/simple
   ```

2. Review and update the configuration in `main.tf` as needed:
   - Adjust VPC CIDR block (`vpc_cidr`) if needed
   - Modify public and private subnet CIDR blocks (`public_subnet_cidrs` and `private_subnet_cidrs`)
   - Uncomment and set specific availability zones if required (`availability_zones`)
   - Adjust NAT Gateway configuration based on requirements
   - Set security group access rules (`allowed_cidr_blocks`)
   - Configure instance type and storage settings as needed

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

### VPC and Networking
- **VPC CIDR**: Default is `10.0.0.0/16` - adjust based on your IP addressing plan
- **Public Subnets**: Default is `["10.0.101.0/24", "10.0.102.0/24"]` - used for NAT Gateways
- **Private Subnets**: Default is `["10.0.1.0/24", "10.0.2.0/24"]` - where VDI instances are deployed
- **NAT Gateway**: Enable/disable NAT Gateway for private subnet internet access
- **Single NAT Gateway**: Use one NAT Gateway for all private subnets to reduce costs

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
- RDP and NICE DCV access is restricted to private networks (10.0.0.0/8)
- The instance is deployed in a private subnet with NAT Gateway for outbound internet access
- No public IP is assigned to the instance by default
- EBS encryption is enabled for all volumes

## Accessing the VDI Instance

Since the VDI instance is deployed in a private subnet, you'll need one of the following methods to access it:

1. **Bastion Host**: Deploy a bastion host in one of the public subnets and connect through it
2. **AWS Systems Manager Session Manager**: Connect through the AWS console without needing direct network access
3. **VPN Connection**: Set up a VPN to connect to resources in the private subnet
4. **Direct Connect**: For enterprise environments, consider using AWS Direct Connect

## Outputs

After deployment, the following information will be available:

### VPC and Networking
- `vpc_id`: The ID of the created VPC
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs
- `internet_gateway_id`: ID of the Internet Gateway
- `nat_gateway_ids`: List of NAT Gateway IDs

### VDI Instance
- `vdi_instance_id`: The EC2 instance ID
- `vdi_private_ip`: The private IP address of the instance
- `vdi_public_ip`: The public IP address (if assigned)
- `ami_used`: Information about the AMI used
- `security_group_id`: The security group ID
- `credentials_secret_id`: The ID of the AWS Secrets Manager secret containing credentials

## Cost Considerations

- **NAT Gateway**: NAT Gateways incur hourly charges and data processing fees
- **VDI Instances**: `g4dn.2xlarge` instances can be expensive. Consider using smaller instance types for development/testing
- **Storage**: GP3 volumes with high IOPS/throughput settings increase costs
- **Cost Saving Options**:
  - Set `single_nat_gateway = true` to use one NAT Gateway for all private subnets
  - Consider using Spot instances for non-production VDI workloads
  - Shut down instances when not in use

## Troubleshooting

### VPC Creation Issues
If VPC creation fails:
1. Check that you have sufficient permissions to create VPC resources
2. Verify the CIDR blocks don't overlap with existing VPCs
3. Ensure the specified availability zones are valid for your region
4. Check AWS service quotas for VPC resources

### NAT Gateway Issues
If instances in private subnets cannot access the internet:
1. Check the NAT Gateway status in the AWS Console
2. Verify the route tables for private subnets include routes to the NAT Gateway
3. Check that the Internet Gateway is properly attached to the VPC
4. Verify the Elastic IP for the NAT Gateway is properly allocated

### AMI Not Found
If you get an error about the AMI not being found:
1. Ensure the Packer build completed successfully
2. Check that the AMI is in the same AWS region
3. Verify the `ami_prefix` variable matches your AMI naming convention

### Network Connectivity Issues
If you can't connect to the instance:
1. Check security group rules
2. Verify the instance is in the private subnet
3. Ensure you have a proper method to access the private subnet (bastion host, VPN, SSM)
4. Check that the Windows firewall allows RDP connections

### Instance Launch Failures
If the instance fails to launch:
1. Check the instance type is available in your region/AZ
2. Verify you have sufficient EC2 limits
3. Check the subnet has available IP addresses
4. Review CloudTrail logs for detailed error messages
