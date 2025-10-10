# Unity Build Pipeline

This sample demonstrates how to deploy a complete Unity build pipeline on AWS using the Cloud Game Development Toolkit. This configuration is designed for production Unity game development workflows and includes version control, CI/CD, asset acceleration, license management, and artifact storage.

## Architecture Overview

This Unity build pipeline consists of the following components:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Unity Build Pipeline                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │   Perforce   │  │   TeamCity   │  │    Unity     │              │
│  │              │  │              │  │              │              │
│  │  • P4 Server │  │  • Server    │  │  • Accelera- │              │
│  │  • P4 Auth   │  │  • Agents    │  │    tor       │              │
│  │              │  │              │  │  • License   │              │
│  │              │  │              │  │    Server    │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
│                                                                       │
│                    ┌──────────────────────┐                         │
│                    │   S3 Artifacts       │                         │
│                    │   Bucket             │                         │
│                    └──────────────────────┘                         │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Components

1. **Perforce (Version Control)**
   - P4 Server (Helix Core) for source code management
   - P4 Auth (Helix Authentication Service) for SSO integration
   - Deployed on ECS with persistent EBS storage

2. **TeamCity (CI/CD)**
   - TeamCity Server for build orchestration
   - Auto-scaling build agents on Fargate
   - Integration with Perforce for source control

3. **Unity Accelerator**
   - Caches Unity Library folder artifacts
   - Reduces import times for distributed teams
   - Deployed on ECS with persistent storage

4. **Unity Floating License Server**
   - Manages Unity Pro/Enterprise licenses
   - Supports concurrent license checkout
   - Deployed on ECS with high availability

5. **S3 Artifacts Bucket**
   - Stores build outputs (executables, asset bundles)
   - Lifecycle policies for cost optimization
   - Versioning enabled for rollback capability

## Features

- **Complete CI/CD Pipeline**: From code commit to build artifact
- **Version Control**: Enterprise-grade Perforce deployment
- **Build Acceleration**: Unity Accelerator for faster iteration
- **License Management**: Floating license server for team collaboration
- **Secure Access**: HTTPS everywhere with SSL/TLS certificates
- **DNS Integration**: Custom domain names for all services
- **High Availability**: Multi-AZ deployments where applicable
- **Cost Optimized**: Auto-scaling and right-sized resources

## Prerequisites

Before deploying this pipeline, ensure you have:

1. **Tools Installed**
   - [Terraform CLI](https://developer.hashicorp.com/terraform/install) (>= 1.0)
   - [Packer CLI](https://developer.hashicorp.com/packer/install) (for AMI creation)
   - [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

2. **AWS Account**
   - AWS account with appropriate permissions
   - AWS CLI configured with credentials
   - Sufficient service quotas for ECS, EC2, and RDS

3. **Domain and DNS**
   - Route53 hosted zone for your domain
   - Ability to validate SSL certificates via DNS

4. **Unity Licensing**
   - Unity Floating License Server binaries
   - Valid Unity Pro or Enterprise license file

## Deployment Guide

### Phase 1: Predeployment

#### Step 1: Create Perforce Server AMI

The Perforce module requires a custom AMI with Perforce Helix Core pre-installed.

> **Important**: If building on Windows, use WSL or a Unix-based system to avoid line ending issues with shell scripts.

```bash
# Navigate to the Packer template directory
cd assets/packer/perforce/p4-server

# Initialize Packer
packer init perforce_x86.pkr.hcl

# Build the AMI (this will use your default AWS region)
packer build perforce_x86.pkr.hcl
```

Take note of the AMI ID from the output. You'll need this for the Terraform configuration.

> **Note**: The AMI must be created in the same AWS region where you plan to deploy the pipeline.

#### Step 2: Create Route53 Hosted Zone

This pipeline requires a Route53 hosted zone for DNS records and SSL certificate validation.

**Option A: Register a new domain with Route53**
- Follow the [Route53 domain registration guide](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/domain-register.html)
- A hosted zone is automatically created

**Option B: Use an existing domain**
- Follow the guide to [make Route53 the DNS service](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/MigratingDNS.html)
- Create a hosted zone for your domain

Your services will be accessible at subdomains:
- `perforce.yourdomain.com` - Perforce server
- `auth.perforce.yourdomain.com` - P4 Auth
- `teamcity.yourdomain.com` - TeamCity server
- `unity-accelerator.yourdomain.com` - Unity Accelerator
- `unity-license.yourdomain.com` - Unity License Server

#### Step 3: Prepare Unity License Server Files

Place your Unity license server files in a location accessible during deployment:

1. Unity Floating License Server binaries (download from Unity)
2. Your `services-config.json` license file
3. Any required SSL certificates for the license server

These will be referenced in the Terraform configuration.

### Phase 2: Deployment

#### Step 1: Configure Variables

Navigate to the unity-build-pipeline directory and create a `terraform.tfvars` file:

```bash
cd samples/unity-build-pipeline
```

Create `terraform.tfvars`:

```hcl
route53_public_hosted_zone_name = "yourdomain.com"
perforce_ami_id                 = "ami-xxxxxxxxxxxxx"  # From Packer output
region                          = "us-east-1"          # Your target region
```

#### Step 2: Review and Customize locals.tf

Edit `locals.tf` to customize:
- Subdomain names
- VPC CIDR blocks
- TeamCity agent configurations
- Unity Accelerator cache size
- Tags and naming conventions

#### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads required providers and modules.

#### Step 4: Deploy the Pipeline

```bash
# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

The deployment takes approximately 15-20 minutes. Terraform will:
1. Create VPC and networking infrastructure
2. Deploy Perforce with P4 Server and P4 Auth
3. Deploy TeamCity server and agents
4. Deploy Unity Accelerator and License Server
5. Create S3 bucket for artifacts
6. Configure DNS records and SSL certificates

### Phase 3: Postdeployment

#### Step 1: Configure Perforce (P4 Server)

**Retrieve Administrator Credentials**:

```bash
# Get the Perforce super user credentials from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw perforce_super_user_secret_arn) \
  --query SecretString \
  --output text
```

**Initial Connection**:

```bash
# Set your P4PORT environment variable
export P4PORT=$(terraform output -raw p4_server_connection_string)

# Login with super user credentials
p4 login

# Create your first depot and users
p4 depot -t stream -o | p4 depot -i
p4 user -f <username>
```

#### Step 2: Configure P4 Auth (Identity Provider)

Navigate to the P4 Auth admin UI:

```bash
# Get the admin credentials
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw p4_auth_admin_secret_arn) \
  --query SecretString \
  --output text
```

Visit `https://auth.perforce.yourdomain.com/admin` and configure your identity provider:
- SAML 2.0
- OpenID Connect
- LDAP/Active Directory

#### Step 3: Configure TeamCity

**Access TeamCity**:

Visit `https://teamcity.yourdomain.com`

**Initial Setup**:
1. Complete the setup wizard
2. Create an administrator account
3. Configure database connection (RDS endpoint provided in outputs)

**Configure Perforce Integration**:
1. Navigate to Administration → VCS Roots
2. Add a new Perforce VCS root
3. Use connection string: `ssl:perforce.yourdomain.com:1666`
4. Configure authentication (use P4 Auth SSO)

**Configure Build Agents**:
- Agents will automatically register with the TeamCity server
- Configure agent pools based on build requirements
- Install Unity Hub and Unity Editor on agents if not using custom AMIs

#### Step 4: Configure Unity Accelerator

**Access Unity Accelerator**:

Visit `https://unity-accelerator.yourdomain.com`

**Configure Unity Editor**:

In Unity Editor preferences:
1. Go to Preferences → Asset Pipeline → Cache Server
2. Set mode to "Remote"
3. Enter IP: `unity-accelerator.yourdomain.com`
4. Port: `10080`
5. Enable "Download" and "Upload"

#### Step 5: Configure Unity License Server (Optional)

The Unity Floating License Server is optional - only deploy if you have Unity Pro/Enterprise licenses. Skip if you didn't set `unity_license_server_file_path` during deployment.

**Register the license server with Unity:**

1. Download the server registration request file:
   ```bash
   wget $(terraform output -raw unity_license_server_registration_request_url) \
     -O server-registration-request.xml
   ```

2. Upload `server-registration-request.xml` to https://id.unity.com/ and download the licenses zip file Unity provides

3. Upload the licenses zip to S3 (keep the original filename):
   ```bash
   aws s3 cp Unity_v202x.x_Linux.zip \
     s3://$(terraform output -raw unity_license_server_s3_bucket)/
   ```

4. Verify license import in the dashboard:
   ```bash
   # Get dashboard URL
   echo $(terraform output -raw unity_license_server_url)

   # Get admin password
   aws secretsmanager get-secret-value \
     --secret-id $(terraform output -raw unity_license_server_dashboard_password_secret_arn) \
     --query SecretString --output text
   ```

The build agents are automatically configured with the license server URL via the `UNITY_LICENSE_SERVER_URL` environment variable. Unity will check out licenses during builds and return them when complete.

#### Step 6: Create Your First Build Configuration

In TeamCity:

1. Create a new project
2. Add build configuration
3. Configure VCS root (Perforce)
4. Add build steps:
   ```bash
   # Example Unity build command
   /opt/unity/Editor/Unity \
     -quit \
     -batchmode \
     -projectPath . \
     -buildTarget Android \
     -executeMethod BuildScript.Build
   ```
5. Configure artifact paths
6. Add artifact upload to S3:
   ```bash
   aws s3 cp build/ s3://$(terraform output -raw artifacts_bucket_name)/builds/$BUILD_NUMBER/ --recursive
   ```

#### Step 7: Verify End-to-End Pipeline

1. Make a commit to Perforce
2. Trigger a TeamCity build
3. Verify Unity Accelerator cache usage (check logs)
4. Verify license checkout from license server
5. Confirm artifacts uploaded to S3 bucket

## Architecture Details

### Networking

```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│   └── NAT Gateways, Load Balancers
├── Private Subnets (10.0.3.0/24, 10.0.4.0/24)
│   └── ECS Services, RDS, Build Agents
└── DNS
    └── Private Route53 zone for internal service discovery
```

### Security

- **Encryption**: All data encrypted at rest and in transit
- **Network Isolation**: Services deployed in private subnets
- **Security Groups**: Least privilege access between services
- **Secrets Management**: Credentials stored in AWS Secrets Manager
- **HTTPS**: All public endpoints use TLS 1.2+
- **IAM Roles**: Task-specific roles with minimal permissions

### High Availability

- **Multi-AZ**: RDS and load balancers span availability zones
- **Auto Scaling**: TeamCity agents scale based on queue depth
- **Health Checks**: Load balancer health checks for all services
- **Backup**: Automated RDS snapshots for Perforce metadata
- **Storage**: EBS volumes with snapshots for critical data

### Cost Optimization

- **Right-Sizing**: Instance types optimized for workload
- **Auto Scaling**: Agents scale down when idle
- **S3 Lifecycle**: Artifacts transition to cheaper storage tiers
- **Spot Instances**: Optional for TeamCity build agents
- **Scheduling**: Can stop/start non-critical services outside work hours

## Build Agent Storage Strategies

TeamCity build agents need access to source code and Unity assets. This sample uses ephemeral storage by default, but larger studios should consider persistent storage for performance.

### Ephemeral Storage (Current Default)

**How it works:** Each agent gets 50GB that's wiped when the container stops. Every new agent downloads the full repository and re-imports all Unity assets.

**Best for:** Small teams, infrequent builds, demos
**Cost:** $0/month
**Build overhead:** 5-15 minutes per build (full P4 sync + Unity import)

### EFS Persistent Storage

**How it works:** Mount a shared EFS volume to `/opt/buildAgent/work`. TeamCity creates a unique working directory per agent (hash-based naming like `a54a2cadb9b4d269`). Each agent maintains its own Perforce workspace and Unity Library cache on EFS, persisting across container restarts.

**Storage pattern:** With 5 agents, you'll have 5 separate directories on EFS, each containing a full P4 workspace + Unity cache. Total storage = (project size + Unity cache) × number of agents.

**Setup:**
1. Create EFS file system in your VPC
2. Mount EFS to `/opt/buildAgent/work` in agent task definition
3. TeamCity automatically isolates each agent to its own subdirectory
4. First build per agent syncs fully; subsequent builds sync incrementally

**Best for:** Medium teams (10-50 devs), frequent builds
**Cost:** ~$5-30/month (15-100GB per agent × agent count)
**Build overhead:** 30 seconds - 2 minutes (incremental sync + Unity cache reuse)

### NetApp ONTAP FlexClone

**How it works:** Run a scheduled job (Lambda/ECS task) that maintains a "golden" FlexVol on FSx for NetApp ONTAP—fully synced to latest Perforce changelist with Unity Library pre-imported. When a build starts, create an instant FlexClone (writable snapshot) and attach it to the agent. Agent works on the clone in isolation. After the build, delete the clone.

**Storage pattern:** One golden volume (repository + Unity cache) + thin clones for active builds. 100GB repo with 10 parallel builds = 100GB parent + ~10GB deltas (not 1TB).

**Setup:**
1. Deploy FSx for NetApp ONTAP in your VPC
2. Create golden volume update automation (nightly or on-demand)
3. Integrate TeamCity with NetApp API to create/destroy clones per build
4. Mount clone as `/opt/buildAgent/work` when agent starts

**Update strategy:** Golden volume updates on schedule (e.g., nightly) or triggered by significant P4 changes. Builds use snapshot from last update, plus incremental P4 sync for any new changes.

**Best for:** Large teams (50+ devs), high build frequency, large repos (100GB+), snapshot-based testing
**Cost:** ~$230+/month (1TB minimum)
**Build overhead:** < 30 seconds (clone creation + small P4 delta sync)

### Quick Comparison

| Approach | Monthly Cost | Storage Per Agent | Best Build Frequency |
|----------|--------------|-------------------|---------------------|
| **Ephemeral** | $0 | 0 (wiped) | < 10/day |
| **EFS** | $5-30/agent | Full copy per agent | 10-100/day |
| **NetApp** | $230+ | Shared + thin deltas | 100+/day |

**Recommendation:** Start with ephemeral. Add EFS when builds exceed 10/day. Consider NetApp only at enterprise scale (50+ agents, 100GB+ repos).

## Outputs

After deployment, Terraform provides these outputs:

```bash
# Service URLs
terraform output perforce_connection_string
terraform output teamcity_url
terraform output unity_accelerator_url
terraform output unity_license_server_url

# Resource identifiers
terraform output artifacts_bucket_name
terraform output vpc_id
terraform output private_subnet_ids

# Security
terraform output perforce_admin_secret_arn
terraform output teamcity_admin_secret_arn
```

## Maintenance

### Updating Components

```bash
# Update Terraform configuration
git pull

# Review changes
terraform plan

# Apply updates
terraform apply
```

### Scaling

**TeamCity Agents**:
Edit `locals.tf` and modify `teamcity_agent_count` or enable auto-scaling.

**Unity Accelerator**:
Increase cache size by modifying `unity_accelerator_cache_size_gb` in `locals.tf`.

**Perforce Storage**:
Extend EBS volume size through AWS Console or CLI, then resize filesystem.

### Monitoring

Key metrics to monitor:
- TeamCity build queue depth and agent utilization
- Unity Accelerator cache hit rate
- Perforce disk usage and connection count
- S3 bucket size and request rates
- RDS CPU, memory, and connection count

### Backup and Disaster Recovery

**Perforce**:
- Daily automated snapshots of EBS volumes
- RDS automated backups (7-day retention)
- Export metadata with `p4 admin checkpoint`

**TeamCity**:
- RDS automated backups
- Configuration exported to S3 (manual)

**S3 Artifacts**:
- Versioning enabled
- Cross-region replication (optional)

## Troubleshooting

### Common Issues

**Perforce connection refused**:
- Check security group rules allow port 1666
- Verify P4 Server service is running in ECS
- Check DNS resolution

**TeamCity agents not connecting**:
- Verify server URL in agent configuration
- Check security groups allow agent-to-server communication
- Review agent logs in CloudWatch

**Unity Accelerator not caching**:
- Verify Unity Editor configuration
- Check accelerator logs for errors
- Ensure port 10080 is accessible

**License server not responding**:
- Verify service is running in ECS
- Check license file validity
- Review license server logs

### Logs

All services log to CloudWatch Logs:

```bash
# View Perforce logs
aws logs tail /ecs/perforce-server --follow

# View TeamCity logs
aws logs tail /ecs/teamcity-server --follow

# View Unity Accelerator logs
aws logs tail /ecs/unity-accelerator --follow
```

## Cleanup

To destroy all resources:

```bash
# Destroy all Terraform-managed resources
terraform destroy
```

**Note**: This will NOT delete:
- AMIs created with Packer
- Route53 hosted zone
- Manual secrets in Secrets Manager
- EBS snapshots (if retention configured)

Delete these manually if needed.

## Cost Estimate

Approximate monthly costs (us-east-1, assuming 8x5 usage):

| Component | Configuration | Monthly Cost |
|-----------|--------------|--------------|
| Perforce (ECS + RDS) | db.t3.medium + EBS | ~$150 |
| TeamCity (ECS + RDS) | 2x agents, db.t3.medium | ~$200 |
| Unity Accelerator | ECS + 500GB EBS | ~$80 |
| Unity License Server | ECS | ~$50 |
| S3 Artifacts | 1TB storage | ~$25 |
| VPC & Networking | NAT Gateway, data transfer | ~$45 |
| **Total** | | **~$550/month** |

*Costs vary based on usage, region, and configuration. Enable auto-scaling and stop non-critical services outside work hours to reduce costs.*

## Security Considerations

### Secrets Management
- Never commit credentials to Git
- Rotate secrets regularly
- Use AWS Secrets Manager for all credentials
- Enable audit logging for secret access

### Network Security
- Deploy in private subnets
- Use security groups for least privilege access
- Enable VPC Flow Logs for traffic analysis
- Consider AWS PrivateLink for service endpoints

### Access Control
- Use IAM roles instead of access keys
- Enable MFA for administrative access
- Implement least privilege principle
- Use P4 Auth for centralized authentication

### Compliance
- Enable CloudTrail for audit logging
- Use AWS Config for compliance monitoring
- Encrypt all data at rest
- Implement backup and retention policies

## Support and Resources

- **CGD Toolkit Documentation**: https://aws-games.github.io/cloud-game-development-toolkit/
- **Report Issues**: https://github.com/aws-games/cloud-game-development-toolkit/issues
- **Discussions**: https://github.com/aws-games/cloud-game-development-toolkit/discussions
- **Perforce Documentation**: https://www.perforce.com/manuals/p4sag/
- **TeamCity Documentation**: https://www.jetbrains.com/help/teamcity/
- **Unity Documentation**: https://docs.unity3d.com/

## Presentation Notes (JetBrains GameDev Day)

This sample demonstrates:

1. **Infrastructure as Code**: Complete pipeline defined in Terraform
2. **AWS Best Practices**: Security, high availability, cost optimization
3. **Game Development Tools**: Purpose-built for Unity workflows
4. **TeamCity Integration**: Seamless CI/CD with JetBrains tools
5. **Scalability**: From indie to AAA studio scale

Key talking points:
- **Speed**: Deploy complete pipeline in ~15 minutes
- **Flexibility**: Modular design, use what you need
- **Production-Ready**: Security and HA built-in
- **Cost-Effective**: Auto-scaling and optimization
- **Community**: Open source, AWS-supported

## License

This sample is part of the Cloud Game Development Toolkit and is licensed under MIT-0. See [LICENSE](../../LICENSE) for details.

---

**Built for game developers, by game developers** 🎮

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.6.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.5.0 |
| <a name="requirement_netapp-ontap"></a> [netapp-ontap](#requirement\_netapp-ontap) | 2.3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.6.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_perforce"></a> [perforce](#module\_perforce) | ../../modules/perforce | n/a |
| <a name="module_teamcity"></a> [teamcity](#module\_teamcity) | ../../modules/teamcity | n/a |
| <a name="module_unity_accelerator"></a> [unity\_accelerator](#module\_unity\_accelerator) | ../../modules/unity/accelerator | n/a |
| <a name="module_unity_license_server"></a> [unity\_license\_server](#module\_unity\_license\_server) | ../../modules/unity/floating-license-server | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.shared](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.shared](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/acm_certificate_validation) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/default_security_group) | resource |
| [aws_ecs_cluster.unity_pipeline_cluster](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.providers](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_eip.nat_gateway_eip](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/eip) | resource |
| [aws_internet_gateway.igw](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat_access](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route) | resource |
| [aws_route.public_internet_access](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route) | resource |
| [aws_route53_record.certificate_validation](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route53_record) | resource |
| [aws_route53_record.p4_server_public](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route53_record) | resource |
| [aws_route53_record.teamcity_public](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route53_record) | resource |
| [aws_route53_record.unity_accelerator_public](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route53_record) | resource |
| [aws_route53_record.unity_license_server_public](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route53_record) | resource |
| [aws_route_table.private_rt](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route_table) | resource |
| [aws_route_table.public_rt](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route_table) | resource |
| [aws_route_table_association.private_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public_rt_asso](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/route_table_association) | resource |
| [aws_security_group.allow_my_ip](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/security_group) | resource |
| [aws_subnet.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/subnet) | resource |
| [aws_subnet.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/subnet) | resource |
| [aws_vpc.unity_pipeline_vpc](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc) | resource |
| [aws_vpc_security_group_ingress_rule.allow_https](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.allow_perforce](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.perforce_from_vpc](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unity_license_server_from_vpc](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unity_license_server_http](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unity_license_server_https](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/availability_zones) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/6.6.0/docs/data-sources/route53_zone) | data source |
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/3.5.0/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The fully qualified domain name of your existing Route53 Hosted Zone (e.g., 'example.com'). | `string` | n/a | yes |
| <a name="input_unity_license_server_file_path"></a> [unity\_license\_server\_file\_path](#input\_unity\_license\_server\_file\_path) | Local path to the Linux version of the Unity Floating License Server zip file. Download from Unity ID portal at https://id.unity.com/. Set to null to skip Unity License Server deployment. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_p4_auth_admin_url"></a> [p4\_auth\_admin\_url](#output\_p4\_auth\_admin\_url) | The URL for the P4Auth service admin page. |
| <a name="output_p4_server_connection_string"></a> [p4\_server\_connection\_string](#output\_p4\_server\_connection\_string) | The connection string for the P4 Server. Set your P4PORT environment variable to this value. |
| <a name="output_perforce_super_user_password_secret_arn"></a> [perforce\_super\_user\_password\_secret\_arn](#output\_perforce\_super\_user\_password\_secret\_arn) | ARN of the secret containing Perforce super user password |
| <a name="output_perforce_super_user_username_secret_arn"></a> [perforce\_super\_user\_username\_secret\_arn](#output\_perforce\_super\_user\_username\_secret\_arn) | ARN of the secret containing Perforce super user username |
| <a name="output_teamcity_url"></a> [teamcity\_url](#output\_teamcity\_url) | The URL for the TeamCity server. |
| <a name="output_unity_accelerator_dashboard_password_secret_arn"></a> [unity\_accelerator\_dashboard\_password\_secret\_arn](#output\_unity\_accelerator\_dashboard\_password\_secret\_arn) | ARN of the secret containing Unity Accelerator dashboard password |
| <a name="output_unity_accelerator_dashboard_username_secret_arn"></a> [unity\_accelerator\_dashboard\_username\_secret\_arn](#output\_unity\_accelerator\_dashboard\_username\_secret\_arn) | ARN of the secret containing Unity Accelerator dashboard username |
| <a name="output_unity_accelerator_url"></a> [unity\_accelerator\_url](#output\_unity\_accelerator\_url) | The URL for the Unity Accelerator dashboard. |
| <a name="output_unity_license_server_dashboard_password_secret_arn"></a> [unity\_license\_server\_dashboard\_password\_secret\_arn](#output\_unity\_license\_server\_dashboard\_password\_secret\_arn) | ARN of the secret containing Unity License Server dashboard password (if deployed) |
| <a name="output_unity_license_server_registration_request_url"></a> [unity\_license\_server\_registration\_request\_url](#output\_unity\_license\_server\_registration\_request\_url) | Presigned URL for downloading the server-registration-request.xml file (valid for 1 hour, if deployed) |
| <a name="output_unity_license_server_services_config_url"></a> [unity\_license\_server\_services\_config\_url](#output\_unity\_license\_server\_services\_config\_url) | Presigned URL for downloading the services-config.json file (valid for 1 hour, if deployed) |
| <a name="output_unity_license_server_url"></a> [unity\_license\_server\_url](#output\_unity\_license\_server\_url) | The URL for the Unity License Server dashboard (if deployed). |
<!-- END_TF_DOCS -->
