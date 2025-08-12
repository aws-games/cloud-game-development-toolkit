# VDI (Virtual Desktop Infrastructure) Module

This Terraform module creates a Virtual Desktop Infrastructure (VDI) setup on AWS using EC2 instances backed by EBS storage. The module is designed to work with AMIs created by the `windows-server-2025` Packer template.

## Features

- **VPC Management**: Create a new VPC with public and private subnets or use an existing VPC
- **EC2 Instance**: Configurable instance type with GPU support (default: g4dn.2xlarge)
- **EBS Storage**: 512GB encrypted root volume with configurable type and performance, plus an additional volume for file storage
- **Security**: Security group with configurable access rules for RDP and NICE DCV
- **IAM Integration**: IAM role and instance profile with SSM permissions for management
- **Launch Template**: Reusable launch template for consistent deployments
- **AMI Options**: Use auto-discovery or provide a custom AMI ID
- **Key Pair Management**: Automatically generates a key pair or uses an existing one
- **Password Management**: Sets a custom administrator password for Windows instances

## Architecture

The module creates a multi-user VDI environment with individual workstations:

**Per User:**
- Individual EC2 instance with custom specifications
- Dedicated launch template with user-specific configuration
- Individual security groups (or shared ones based on configuration)
- Separate key pairs and credentials stored in Secrets Manager
- Custom storage volumes based on user requirements
- Optional Active Directory domain joining per user

**Shared Resources:**
- IAM role and instance profile for AWS service integration
- SSM document for Active Directory domain joining (when needed)
- VPC and networking infrastructure (provided externally)

**Flexible Configuration:**
- Each user can have different instance types, storage, and networking
- Mixed environments: some users with AD, others standalone
- Role-based configurations with custom overrides
- Individual credential management and access control

## Usage

The VDI module now supports multiple user workstations with individual configurations. Each user can have different instance types, storage, networking, and Active Directory settings.

### Complete Example Configuration

```hcl
module "vdi_workstations" {
  source = "./modules/vdi"

  # Shared Configuration
  project_prefix = "cgd"
  environment    = "dev"
  vpc_id         = "vpc-12345678"  # Your existing VPC ID
  subnets        = ["subnet-12345678", "subnet-87654321"]  # Available subnets

  # Individual User Configurations
  vdi_config = {
    # Developer Workstation - High Performance with AD
    USER1 = {
      # Compute
      ami           = null  # Uses auto-discovered AMI
      instance_type = "g4dn.2xlarge"
      
      # Networking
      availability_zone               = "us-west-2a"
      subnet_id                      = "subnet-12345678"
      associate_public_ip_address    = false
      
      # Security
      create_default_security_groups = true
      allowed_cidr_blocks           = ["10.0.0.0/8"]
      
      # Key Pair and Password Management
      create_key_pair                    = true
      admin_password                     = null  # Will generate random password
      store_passwords_in_secrets_manager = true
      
      # Storage
      volumes = {
        Root = {
          capacity = 512
          type     = "gp3"
          iops     = 4000
        }
        Data = {
          capacity = 1000
          type     = "gp3"
          iops     = 5000
        }
      }
      
      # Active Directory
      join_ad = true
      
      # Tags for user identification and AD creation
      tags = {
        # Required for proper AD user creation
        given_name  = "John"
        family_name = "Smith"
        email       = "john.smith@company.com"
        
        # Additional organizational tags
        department  = "Engineering"
        team        = "Platform"
        role        = "Senior Developer"
        cost_center = "CC-1234"
      }
    }

    # Designer Workstation - Maximum Performance, No AD
    USER2 = {
      # Compute
      ami           = null
      instance_type = "g4dn.4xlarge"  # More powerful for design work
      
      # Networking
      availability_zone               = "us-west-2b"
      subnet_id                      = "subnet-87654321"
      associate_public_ip_address    = false
      
      # Security
      create_default_security_groups = true
      allowed_cidr_blocks           = ["10.0.0.0/8"]
      
      # Key Pair and Password Management
      create_key_pair                    = true
      admin_password                     = null
      store_passwords_in_secrets_manager = true
      
      # Storage - More storage for design files
      volumes = {
        Root = {
          capacity = 1024
          type     = "gp3"
          iops     = 5000
        }
        Projects = {
          capacity = 2000
          type     = "gp3"
          iops     = 6000
        }
        Assets = {
          capacity = 1500
          type     = "gp3"
        }
      }
      
      # No Active Directory
      join_ad = false
      
      # Tags for user identification (no AD for this user)
      tags = {
        given_name  = "Sarah"
        family_name = "Johnson"
        email       = "sarah.johnson@company.com"
        
        # Additional organizational tags
        department  = "Design"
        team        = "Creative"
        role        = "Senior Designer"
        cost_center = "CC-5678"
      }
    }
  }

  # Shared Active Directory Configuration (for users with join_ad = true)
  directory_id        = "d-1234567890"
  directory_name      = "corp.example.com"
  dns_ip_addresses    = ["10.0.1.100", "10.0.1.101"]
  ad_admin_password   = var.domain_admin_password
  shared_temp_password = var.shared_temp_password  # Temporary password for all new users

  # Shared settings
  ami_prefix            = "windows-server-2025"
  ebs_encryption_enabled = true

  tags = {
    Environment = "dev"
    Project     = "VDI"
  }
}

# Template for adding more users - Copy and modify this block
/*
    USER3 = {
      # Compute
      ami           = null  # Uses auto-discovered AMI, or specify "ami-12345678"
      instance_type = "g4dn.xlarge"  # Choose: t3.large, g4dn.xlarge, g4dn.2xlarge, g4dn.4xlarge, etc.
      
      # Networking
      availability_zone               = "us-west-2a"  # Match your subnet's AZ
      subnet_id                      = "subnet-12345678"  # Choose from your available subnets
      associate_public_ip_address    = false  # Usually false for security
      
      # Security
      create_default_security_groups = true  # Creates RDP/DCV access rules
      allowed_cidr_blocks           = ["10.0.0.0/8"]  # Adjust for your network
      
      # Key Pair and Password Management
      create_key_pair                    = true   # Creates new key pair for this user
      admin_password                     = null   # null = generates random password
      store_passwords_in_secrets_manager = true   # Stores credentials securely
      
      # Storage - Define volumes as needed
      volumes = {
        Root = {
          capacity = 512    # Size in GB (30-16384)
          type     = "gp3"  # gp3 recommended for performance
          iops     = 3000   # Optional: IOPS for gp3 volumes
        }
        # Add more volumes as needed:
        # Data = { capacity = 1000, type = "gp3" }
      }
      
      # Active Directory
      join_ad = true  # true = joins AD domain, false = standalone
      
      # Tags for identification and billing
      tags = {
        # User information for AD creation (if join_ad = true)
        given_name  = "Alice"
        family_name = "Wilson"
        email       = "alice.wilson@company.com"
        
        # Additional organizational tags
        department  = "Marketing"
        team        = "Digital"
        role        = "Marketing Manager"
        cost_center = "CC-9999"
      }
    }
*/
```

### Adding More Users

To add additional users, simply add new blocks to the `vdi_config` map following the template above. Each user gets:

- **Individual EC2 instance** with custom specs
- **Shared temporary password** for first-time login (AD users)
- **Automatic AD user creation** with forced password change
- **Custom storage configuration** with multiple volumes
- **Flexible networking** - choose subnet and availability zone
- **Optional Active Directory** joining per user
- **Individual security groups** or shared ones

### Password Management

**For AD Users (`join_ad = true`):**
- All users get the same temporary password initially
- AD users are created **automatically during `terraform apply`**
- Users must change password on first login through Windows
- Login format: `DOMAIN\username` + temporary password

**For Standalone Users (`join_ad = false`):**
- Uses local Windows Administrator account
- Can specify custom password or use temporary password

### User Information for Active Directory Creation

When `join_ad = true`, the module automatically creates AD users with proper attributes. User information is provided through the `tags` section of each user's configuration:

#### Required and Optional User Tags

| Tag Name | Purpose | Required | Default | Example |
|----------|---------|----------|---------|---------|
| `given_name` | First name for AD user | No | Username | `"John"` |
| `family_name` | Last name for AD user | No | `"User"` | `"Doe"` |
| `email` | Email address for AD user | No | `username@domain.com` | `"john.doe@company.com"` |

#### Tag Usage Examples

**Complete User Information:**
```hcl
vdi_config = {
  "jdoe" = {
    # ... instance configuration ...
    join_ad = true
    
    tags = {
      given_name  = "John"                    # First name in AD
      family_name = "Doe"                     # Last name in AD  
      email       = "john.doe@company.com"   # Email in AD
      department  = "Engineering"             # Additional tag (not used for AD)
      role        = "Senior Developer"        # Additional tag (not used for AD)
    }
  }
}
```

**Minimal Configuration (uses defaults):**
```hcl
vdi_config = {
  "alice" = {
    # ... instance configuration ...
    join_ad = true
    
    tags = {
      # No user info tags - will use defaults:
      # given_name = "alice" (username)
      # family_name = "User" 
      # email = "alice@corp.example.com" (username@domain)
      department = "Marketing"
    }
  }
}
```

**Mixed Configuration:**
```hcl
vdi_config = {
  "bob.smith" = {
    # ... instance configuration ...
    join_ad = true
    
    tags = {
      given_name = "Bob"                      # Provided
      # family_name will default to "User"
      email = "bob.smith@company.com"         # Provided
      cost_center = "CC-1234"
    }
  }
}
```

#### How User Information is Used

The module uses these tags to create AD users with proper attributes:

1. **Display Name**: Combines `given_name` and `family_name` → `"John Doe"`
2. **User Principal Name (UPN)**: Uses username and domain → `"jdoe@corp.example.com"`
3. **Email Address**: Uses `email` tag or generates from username → `"john.doe@company.com"`
4. **SAM Account Name**: Uses the configuration key (username) → `"jdoe"`

#### AD User Creation Process

During `terraform apply`, for each user with `join_ad = true`:

1. **User Creation**: Creates AD user with attributes from tags
2. **Password Setting**: Sets the `shared_temp_password` (user must change on first login)
3. **Group Membership**: Automatically adds user to:
   - `Domain Users` (standard AD group)
   - `Remote Desktop Users` (required for DCV access)
4. **Verification**: Confirms user creation and group membership

#### Best Practices for User Tags

**✅ Recommended:**
```hcl
tags = {
  # User identification (for AD)
  given_name  = "John"
  family_name = "Doe" 
  email       = "john.doe@company.com"
  
  # Organizational tags (for AWS billing/management)
  department  = "Engineering"
  team        = "Platform"
  role        = "Senior Developer"
  cost_center = "CC-1234"
  manager     = "jane.smith@company.com"
}
```

**❌ Avoid:**
```hcl
tags = {
  # Don't use special characters in names that might cause AD issues
  given_name = "John-Paul O'Connor"  # Hyphens and apostrophes can cause issues
  
  # Don't use very long names
  family_name = "VeryLongLastNameThatExceedsActiveDirectoryLimits"
  
  # Don't use invalid email formats
  email = "not-an-email"
}
```

#### Troubleshooting User Creation

If AD user creation fails, check:

1. **Required Variables**: Ensure `directory_id`, `directory_name`, and `shared_temp_password` are provided
2. **Tag Format**: Verify user tags don't contain special characters
3. **Email Format**: Ensure email addresses are valid
4. **Permissions**: Verify Terraform has permissions to create AD users
5. **Domain Connectivity**: Ensure the directory is accessible

**View Created Users:**
```bash
# List all users in the directory
aws ds-data list-users --directory-id d-1234567890

# Get specific user details  
aws ds-data describe-user --directory-id d-1234567890 --sam-account-name jdoe

# List user's group memberships
aws ds-data list-groups-for-member --directory-id d-1234567890 --member-name jdoe --member-realm corp.example.com
```

### Automated AD User Creation (FIXED SSM TARGETING)

The module now uses **AWS Systems Manager (SSM)** to automatically create AD users with **proper targeting to domain controllers**:

**During `terraform apply`:**
1. ✅ **AD users are created** on **domain controllers** via SSM (fixed targeting)
2. ✅ **Instances join the domain** via SSM document
3. ✅ **DCV is configured** for AD authentication automatically
4. ✅ **Users can immediately login** with their AD credentials via DCV

**The SSM automation (FIXED):**
- ✅ **Proper SSM Targeting** - User creation runs on domain controllers, not VDI instances
- ✅ **Fully automated** - runs during terraform apply
- ✅ **Creates AD users** with shared temporary password
- ✅ **Forces password change** on first login
- ✅ **Configures DCV authentication** against Active Directory
- ✅ **Sets proper permissions** for domain users in DCV
- ✅ **Handles existing users** - updates password if user exists
- ✅ **Sets proper attributes** - display name, UPN, email, etc.


### Requirements

- **SSM Agent** (pre-installed on Windows AMIs and domain controllers)
- **Domain Controllers** accessible via SSM for user creation
- **Network Connectivity** between VDI instances and domain controllers

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | 6.5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | 6.5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_prefix | The project prefix for this workload | `string` | `"cgd"` | no |
| environment | The current environment (e.g. dev, prod, etc.) | `string` | `"dev"` | no |
| tags | Tags to apply to resources | `map(any)` | See variables.tf | no |
| vpc_id | The ID of the existing VPC to deploy VDI instances into | `string` | n/a | yes |
| subnets | List of subnet IDs available for VDI instances | `list(string)` | n/a | yes |
| vdi_config | Configuration for each VDI user workstation | `map(object)` | n/a | yes |
| ami_prefix | The prefix of the AMI name created by the packer template | `string` | `"windows-server-2025"` | no |
| ebs_encryption_enabled | Whether to enable EBS encryption for all volumes | `bool` | `true` | no |
| ebs_kms_key_id | The KMS key ID to use for EBS encryption | `string` | `null` | no |
| directory_id | ID of AWS Directory Service AD domain | `string` | `null` | no |
| directory_name | Name of AWS Directory Service AD domain | `string` | `null` | no |
| directory_ou | Organizational unit for AD domain | `string` | `null` | no |
| dns_ip_addresses | List of DNS IP addresses for the AD domain | `list(string)` | `[]` | no |
| ad_admin_password | The AD domain administrator password | `string` | `""` | no |
| domain_join_timeout | Timeout in seconds for domain join operation | `number` | `300` | no |

### VDI Config Object Structure

Each user in `vdi_config` supports the following configuration:

| Field | Description | Type | Default | Required |
|-------|-------------|------|---------|:--------:|
| ami | AMI ID to use (null = auto-discover) | `string` | `null` | no |
| instance_type | EC2 instance type | `string` | n/a | yes |
| availability_zone | AZ for the instance | `string` | n/a | yes |
| subnet_id | Subnet ID for the instance | `string` | n/a | yes |
| associate_public_ip_address | Whether to assign public IP | `bool` | `false` | no |
| iam_instance_profile | Custom IAM instance profile | `string` | `null` | no |
| create_default_security_groups | Create default security groups | `bool` | `true` | no |
| existing_security_groups | List of existing security group IDs | `list(string)` | `[]` | no |
| allowed_cidr_blocks | CIDR blocks for access | `list(string)` | `["10.0.0.0/8"]` | no |
| key_pair_name | Existing key pair name | `string` | `null` | no |
| create_key_pair | Create new key pair | `bool` | `true` | no |
| admin_password | Windows admin password | `string` | `null` | no |
| store_passwords_in_secrets_manager | Store credentials in Secrets Manager | `bool` | `true` | no |
| volumes | Storage volumes configuration | `map(object)` | n/a | yes |
| join_ad | Whether to join Active Directory | `bool` | `false` | no |
| tags | User-specific tags | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC being used |
| subnets | The subnet IDs being used |
| vdi_instances | Map of VDI instances with their details (id, private_ip, public_ip, etc.) |
| vdi_security_groups | Map of security groups for VDI instances |
| vdi_launch_templates | Map of launch templates for VDI instances |
| vdi_iam_role_arn | The ARN of the IAM role associated with VDI instances |
| vdi_iam_instance_profile_name | The name of the IAM instance profile |
| key_pairs | Map of key pairs used for VDI instances |
| secrets_manager_secrets | Map of AWS Secrets Manager secrets containing credentials |
| user_configurations | Summary of user configurations (sensitive) |
| ami_info | Information about AMIs used (default and per-user) |
| domain_join_info | Information about AD domain joining |
| ssm_associations | Map of SSM associations for domain joining |
| user_public_ip | The detected public IP address of the user |

## Prerequisites

1. **Packer AMI**: The module expects an AMI created by the `windows-server-2025` Packer template to be available in your AWS account.

2. **VPC and Subnets**: Either:
   - **Option A**: Set `create_vpc = true` to have the module create a new VPC with public and private subnets
   - **Option B**: Set `create_vpc = false` and provide an existing VPC ID and subnet ID

3. **Key Pair and Password**:
   - The module can automatically generate a key pair if `create_key_pair` is set to true
   - The module requires a custom admin password to be specified via the `admin_password` parameter
   - If `store_passwords_in_secrets_manager` is true, credentials are securely stored in AWS Secrets Manager

## Security Considerations

- The module creates a security group with restrictive ingress rules for RDP (3389) and NICE DCV (8443) by default
- EBS encryption is enabled by default
- The instance is configured with an IAM role that has minimal permissions for AWS Systems Manager
- Generated passwords and private keys are securely stored in AWS Secrets Manager
- Consider deploying the instance in a private subnet and using a bastion host or VPN for access

## AMI Options

The module provides two options for selecting the AMI:

### 1. Auto-discovery (Default)

The module uses a data source to automatically discover the most recent AMI created by the Packer template:

```hcl
data "aws_ami" "windows_server_2025_vdi" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["${var.ami_prefix}-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
```

This ensures that the module always uses the latest version of your packer AMI, even when the AMI name includes random strings generated during the Packer build process.

### 2. Custom AMI ID

You can specify a custom AMI ID to use a specific AMI instead of relying on auto-discovery:

```hcl
module "vdi" {
  source = "./modules/vdi"
  
  # ... other configuration ...
  
  # Use a specific AMI
  ami_id = "ami-0123456789abcdef0"
}
```

When `ami_id` is provided, it takes precedence over the auto-discovery mechanism. This is useful when:

- You want to use an AMI from a different account or public AMI
- You need to use a specific version of an AMI rather than the latest
- You have custom AMIs not created by the Packer template

## Remote Access Options

This module supports two main remote access options for Windows VDIs:

### RDP (Remote Desktop Protocol)
- Standard Windows remote desktop protocol
- Port: 3389 (TCP)
- Built-in client available on most operating systems

### NICE DCV
- High-performance remote display protocol optimized for GPU workloads
- Port: 8443 (TCP and UDP for QUIC protocol)
- Better performance than RDP for graphics-intensive applications
- Requires NICE DCV client installation on the client device
- Supports streaming 4K resolution at 60 FPS with low latency

## Key Pair and Password Management

This module provides several options for managing key pairs and administrator passwords:

### Auto-generated Key Pair
When `create_key_pair = true` and `key_pair_name = null`:
- Generates a new RSA key pair
- Stores the private key in AWS Secrets Manager (if enabled)

### Custom Key Pair
When `key_pair_name` is specified (by uncommenting and setting the value in your configuration):
- Uses an existing AWS key pair with the specified name

### Administrator Password
- Requires a password to be specified via the `admin_password` parameter
- Sets the password via user data script during instance boot
- Stores the password securely in AWS Secrets Manager (if enabled)

## Accessing Generated Credentials

If `store_passwords_in_secrets_manager = true`, you can retrieve credentials using:

```bash
aws secretsmanager get-secret-value --secret-id <secret-id> --query 'SecretString' --output text | jq .
```

Replace `<secret-id>` with the value of the `secrets_manager_secret_id` output.