# External Client VPN Example

This example shows how to use the VDI module with your **existing** Client VPN endpoint instead of creating a new one.

## Use Case

- You already have a Client VPN endpoint configured
- You want to add VDI workstations accessible via your existing VPN
- You manage VPN users/certificates separately from VDI

## Key Configuration

```hcl
module "vdi" {
  # IMPORTANT: Disable built-in Client VPN creation
  enable_private_connectivity = false
  
  # Users marked as private (but no VPN infrastructure created)
  users = {
    alice = {
      connectivity_type = "private"  # Uses your existing VPN
    }
  }
  
  # Security groups allow your VPN CIDR
  workstations = {
    workstation-01 = {
      allowed_cidr_blocks = ["192.168.0.0/16"]  # Your VPN CIDR
    }
  }
}
```

## Prerequisites

1. **Existing Client VPN endpoint** with network associations to your VPC
2. **VPN users configured** in your existing Client VPN
3. **VPC and subnets** where VDI workstations will be deployed

## Deployment

1. **Configure variables:**
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

2. **Deploy:**
```bash
terraform init
terraform plan
terraform apply
```

## Access Pattern

1. **Connect to your existing VPN** using your existing .ovpn files
2. **Access workstations** via private IPs or DNS names:
   - Direct IP: `10.0.1.100:8443` (DCV web console)
   - DNS: `workstation-01.vdi.internal:8443`

## What This Example Does

✅ **Creates VDI workstations** in private subnets  
✅ **Configures security groups** to allow your VPN CIDR  
✅ **Creates internal DNS records** for easy access  
✅ **Sets up user accounts** with Secrets Manager passwords  
❌ **Does NOT create Client VPN** (uses your existing one)  
❌ **Does NOT generate .ovpn files** (uses your existing process)  

## Comparison with Built-in VPN

| Feature | Built-in VPN | External VPN |
|---------|-------------|--------------|
| VPN Infrastructure | ✅ Created by module | ❌ You manage separately |
| Certificate Management | ✅ Auto-generated | ❌ You manage separately |
| .ovpn File Generation | ✅ Stored in S3 | ❌ You manage separately |
| VDI Workstations | ✅ Created by module | ✅ Created by module |
| User Management | ✅ Secrets Manager | ✅ Secrets Manager |
| Internal DNS | ✅ Auto-configured | ✅ Optional in this example |

Choose **built-in VPN** for simple, all-in-one deployment.  
Choose **external VPN** when you need to integrate with existing VPN infrastructure.