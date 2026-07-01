# Multi-Region Horde Deployment

Deploy Unreal Engine Horde with a single control plane in one AWS region and distributed build agents across multiple regions. Artifacts are stored locally via S3 Multi-Region Access Points (MRAP) and replicated bidirectionally for global access.

## Overview

This example deploys:

- **Horde server** (ECS Fargate) in a primary region with DocumentDB + ElastiCache
- **Build agents** (EC2 Auto Scaling Groups) in primary and secondary regions
- **S3 MRAP** routing artifact uploads/downloads to the nearest bucket
- **Bidirectional S3 replication** so artifacts are accessible from any region

```
                    ┌─────────────────────────────┐
                    │   Horde Server (us-east-1)  │
                    │   ECS + DocumentDB + Redis  │
                    │   Single control plane      │
                    └──────────┬──────────────────┘
                               │
                ┌──────────────┼──────────────────┐
                │ gRPC (443)   │                  │ gRPC (443)
                ▼              │                  ▼
     ┌──────────────────┐     │       ┌──────────────────┐
     │  US Agent Pool   │     │       │  EU Agent Pool   │
     │  us-east-1       │     │       │  eu-west-1       │
     │  EC2 ASG         │     │       │  EC2 ASG         │
     └────────┬─────────┘     │       └────────┬─────────┘
              │               │                │
              ▼               │                ▼
     ┌──────────────────┐     │       ┌──────────────────┐
     │  S3 (us-east-1)  │◄────┼──────►│  S3 (eu-west-1)  │
     └──────────────────┘  Bidir CRR  └──────────────────┘
              ▲                                 ▲
              └─────────── S3 MRAP ────────────┘
                     (routes to nearest)
```

**Problems solved:**

- EU builds execute on EU compute — no cross-Atlantic source sync or build latency
- Artifacts upload at local speed (~milliseconds vs. 14+ minutes for 100 GB cross-region)
- All jobs visible in a single dashboard regardless of execution region
- Developers in any region download artifacts from the nearest S3 bucket

## Prerequisites

| Requirement | Details |
|-------------|---------|
| AWS account | IAM permissions in both target regions |
| Terraform | >= 1.0 (tested with 1.9+) |
| AWS provider | ~> 6.6 |
| Docker | For building the patched Horde server image |
| Unreal Engine source | Access to `Engine/Source/Programs/Horde/` (for Horde source + `Setup.sh`) |
| Route53 hosted zone | Public hosted zone for your domain (e.g., `example.com`) |
| ECR repository | In the primary region, to host the patched Horde image |

The ACM certificate is auto-created and validated by this example via Route53 DNS.

## Building the Patched Image

Horde requires two small patches (~45 lines total) to support multi-region storage and fleet management. The patches are located in the `patches/` directory of the research repository.

```bash
# 1. Clone Unreal Engine source (you need access via Epic Games)
#    Only the Horde subdirectory is needed:
#    Engine/Source/Programs/Horde/

# 2. Apply patches from the root of your UE source tree
git apply patches/0001-mrap-sigv4a-support.patch
git apply patches/0002-fleet-manager-region.patch

# 3. Download binary dependencies (required once)
./Setup.sh

# 4. Build the Docker image
cd Engine/
docker build -f Source/Programs/Horde/HordeServer/Dockerfile -t horde-server:multi-region .

# 5. Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker tag horde-server:multi-region <account-id>.dkr.ecr.us-east-1.amazonaws.com/horde-server:multi-region
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/horde-server:multi-region

# 6. Verify patches are included
docker run --rm --entrypoint cat horde-server:multi-region /app/AWSSDK.Extensions.CrtIntegration.dll > /dev/null && echo "Patch 0001: OK"
```

### What the patches do

| Patch | Purpose | Lines |
|-------|---------|-------|
| `0001-mrap-sigv4a-support` | Adds `AWSSDK.Extensions.CrtIntegration` NuGet package and detects MRAP ARNs to configure the S3 client with `UseArnRegion=true` for SigV4a signing | 16 |
| `0002-fleet-manager-region` | Adds optional `Region` field to fleet manager settings, enabling cross-region ASG management from the single control plane | 29 |

## Deployment (Phased)

Deploy incrementally. **Do not proceed to the next phase until the checkpoint passes.**

```bash
cd modules/unreal/horde/examples/multi-region/
terraform init
```

### Phase 1: Server Only

Deploys Horde server, DocumentDB, ElastiCache, ALBs, VPC, and DNS.

```bash
terraform apply \
  -var="image=<account-id>.dkr.ecr.<primary-region>.amazonaws.com/horde-server:multi-region" \
  -var="root_domain_name=example.com"
```

> Deploys ~75 resources. Takes 10-15 minutes (DocumentDB creation is the bottleneck).

**Checkpoint 1a — Terraform outputs:**
```bash
terraform output
```
Expected:
```
external_alb_dns = "cgd-unreal-horde-ext-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com"
horde_url = "https://horde.example.com"
```

**Checkpoint 1b — Server responds:**
```bash
curl -sk https://horde.example.com/api/v1/server/info | jq .
```
Expected:
```json
{
  "apiVersion": 4,
  "serverVersion": "1.0.0",
  "plugins": [
    {"name": "storage", "loaded": true},
    {"name": "compute", "loaded": true},
    {"name": "tools", "loaded": true}
  ]
}
```

> **If this fails:** Check ECS service events (`aws ecs describe-services --cluster cgd-unreal-horde-cluster --services cgd-unreal-horde`). Common issues: DocumentDB not ready yet (wait 2 min and retry), ACM cert not validated (check Route53 CNAME).

**Checkpoint 1c — Storage plugin loaded:**
```bash
curl -sk https://horde.example.com/api/v1/tools | jq .
```
Expected:
```json
{"tools": [{"id": "horde-agent", "name": "Horde Agent", "public": true}]}
```

> If tools list is empty, the `forceConfigUpdateOnStartup=true` env var may not be set. Check the ECS task definition.

---

### Phase 2: Enable MRAP

Creates S3 buckets in both regions, configures bidirectional replication, and provisions the Multi-Region Access Point.

```bash
terraform apply \
  -var="image=<account-id>.dkr.ecr.<primary-region>.amazonaws.com/horde-server:multi-region" \
  -var="root_domain_name=example.com" \
  -var="enable_mrap=true"
```

> MRAP provisioning takes ~5 minutes.

**Checkpoint 2a — MRAP exists:**
```bash
terraform output mrap_arn
```
Expected: `arn:aws:s3::<account-id>:accesspoint/<alias>.mrap`

**Checkpoint 2b — Write routing works (from primary region):**
```bash
echo "checkpoint-test" | aws s3 cp - \
  s3://$(terraform output -raw mrap_arn)/test/checkpoint.txt \
  --region us-east-1

# Verify it landed in the primary bucket:
aws s3 ls s3://horde-artifacts-us-east-1-$(aws sts get-caller-identity --query Account --output text)/test/ --region us-east-1
```
Expected: `checkpoint.txt` appears in the us-east-1 bucket.

**Checkpoint 2c — CRR replicates:**
```bash
# Wait 5 seconds, then check the secondary bucket:
sleep 5
aws s3 ls s3://horde-artifacts-eu-west-1-$(aws sts get-caller-identity --query Account --output text)/test/ --region eu-west-1
```
Expected: `checkpoint.txt` appears in the eu-west-1 bucket (replica).

> **If CRR doesn't replicate:** Check IAM replication roles and bucket versioning. Both buckets must have versioning enabled.

**Checkpoint 2d — Clean up test object:**
```bash
aws s3 rm s3://$(terraform output -raw mrap_arn)/test/checkpoint.txt --region us-east-1
```

---

### Phase 3: Enable Primary Agents

Deploys EC2 Auto Scaling Group with build agents in the primary region.

```bash
terraform apply \
  -var="image=<account-id>.dkr.ecr.<primary-region>.amazonaws.com/horde-server:multi-region" \
  -var="root_domain_name=example.com" \
  -var="enable_mrap=true" \
  -var="enable_agents=true"
```

**Checkpoint 3a — ASG created:**
```bash
aws autoscaling describe-auto-scaling-groups --region us-east-1 \
  --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `horde`)].{Name:AutoScalingGroupName,Min:MinSize,Max:MaxSize}'
```
Expected: One ASG with Min=0, Max=2.

**Checkpoint 3b — Upload agent software:**

Before agents can enroll, upload the agent binary:
```bash
# Build agent from source (same Horde source tree)
cd Engine/Source/Programs/Horde
dotnet publish HordeAgent/HordeAgent.csproj -c Release -r linux-x64 --self-contained -o /tmp/horde-agent
cd /tmp/horde-agent && zip -r /tmp/horde-agent.zip .

# Upload to Horde
curl -sk -X POST "https://horde.example.com/api/v1/tools/horde-agent/deployments" \
  -F "file=@/tmp/horde-agent.zip;type=application/zip" \
  -F "version=1.0.0"
```
Expected: `{"id": "<deployment-id>"}` with HTTP 200.

**Checkpoint 3c — Agent enrolls:**

Scale ASG to 1 and verify enrollment:
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(aws autoscaling describe-auto-scaling-groups --region us-east-1 \
    --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `horde`)].AutoScalingGroupName' --output text) \
  --desired-capacity 1 --region us-east-1

# Wait 2-3 minutes for agent to boot and enroll, then:
curl -sk https://horde.example.com/api/v1/agents | jq '.[].name'
```
Expected: Agent hostname appears in the list.

> **If agent doesn't appear:** Get a registration token from `https://horde.example.com/api/v1/admin/registrationtoken` and configure it on the agent via SSM.

---

### Phase 4: Enable Secondary Region

Deploys VPC, networking, and agent ASG in the secondary region (eu-west-1).

```bash
terraform apply \
  -var="image=<account-id>.dkr.ecr.<primary-region>.amazonaws.com/horde-server:multi-region" \
  -var="root_domain_name=example.com" \
  -var="enable_mrap=true" \
  -var="enable_agents=true" \
  -var="enable_secondary_region=true"
```

**Checkpoint 4a — EU VPC and ASG created:**
```bash
aws autoscaling describe-auto-scaling-groups --region eu-west-1 \
  --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `horde`)].{Name:AutoScalingGroupName,Min:MinSize,Max:MaxSize}'
```
Expected: One ASG in eu-west-1 with Min=0, Max=2.

**Checkpoint 4b — Fleet manager scales EU ASG:**

The Horde fleet service should detect the EU-Linux pool and manage the ASG. Check CloudTrail:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DescribeAutoScalingGroups \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --region eu-west-1 --query 'Events[0].EventTime'
```
Expected: Recent timestamp (confirms the Horde server is calling eu-west-1 AutoScaling API).

**Checkpoint 4c — EU agent connectivity:**

Scale EU ASG to 1 and verify the agent can reach the Horde server:
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(aws autoscaling describe-auto-scaling-groups --region eu-west-1 \
    --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `horde`)].AutoScalingGroupName' --output text) \
  --desired-capacity 1 --region eu-west-1

# Wait 2-3 minutes, then verify via SSM:
EU_INSTANCE=$(aws ec2 describe-instances --region eu-west-1 \
  --filters "Name=instance-state-name,Values=running" "Name=tag-key,Values=aws:autoscaling:groupName" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

aws ssm send-command --instance-ids $EU_INSTANCE \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["curl -sk https://horde.example.com/api/v1/server/info | head -1"]' \
  --region eu-west-1
```
Expected: Server responds with JSON (confirms cross-region connectivity over public internet).

**Checkpoint 4d — MRAP write routing from EU:**

Verify that an EU-based write lands in the EU bucket:
```bash
aws ssm send-command --instance-ids $EU_INSTANCE \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["echo eu-test | aws s3 cp - s3://arn:aws:s3::<account>:accesspoint/<mrap-alias>.mrap/test/eu-routing.txt"]' \
  --region eu-west-1

# Check ReplicationStatus to confirm it originated in EU:
aws s3api head-object \
  --bucket horde-artifacts-eu-west-1-<account> \
  --key test/eu-routing.txt \
  --region eu-west-1 \
  --query 'ReplicationStatus'
```
Expected: `"COMPLETED"` (this is the source bucket — the write landed here, not in US).

> **If it shows REPLICA:** The write went to the US bucket and replicated to EU. This means the EU instance is routing through a US-based NAT or proxy. Check the VPC's NAT gateway and internet gateway configuration.

---

## All Checkpoints Passed?

**Congratulations!** You have a working multi-region Horde deployment where:
- ✅ Server runs in the primary region with all metadata
- ✅ Agents in both regions connect to the single control plane
- ✅ Artifacts upload to the nearest S3 bucket automatically
- ✅ CRR replicates artifacts to all regions
- ✅ Fleet manager scales agent ASGs across regions

You can now configure BuildGraph templates with region-specific agent types to route jobs to the appropriate regional pool.

## Post-Deployment Steps

### 1. Upload Agent Software

On a fresh deployment, agents download their runtime from the Horde server. Upload the agent tool package:

```bash
# Build the agent tool zip from Horde source
cd Engine/Source/Programs/Horde/HordeAgent
dotnet publish -c Release -o ./publish
cd publish && zip -r horde-agent.zip . && cd ..

# Upload via API
curl -X POST "https://horde.example.com/api/v1/tools/horde-agent" \
  -H "Content-Type: application/zip" \
  --data-binary @publish/horde-agent.zip
```

### 2. Register Secondary Region Agents

EU agents auto-register on first boot via the user-data script baked into the launch template. They connect to the Horde server URL configured in their `appsettings.json`.

To scale the EU fleet:

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw secondary_asg_name) \
  --desired-capacity 1 \
  --region eu-west-1
```

### 3. Configure Agent Properties

Add region properties to agent pools in `globals.json`:

```json
{
  "pools": [
    {
      "id": "us-linux",
      "condition": "region == 'us-east-1'"
    },
    {
      "id": "eu-linux",
      "condition": "region == 'eu-west-1'"
    }
  ]
}
```

## Configuration

### Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `root_domain_name` | string | — | Root domain for the Route53 hosted zone |
| `image` | string | — | ECR URI for the patched Horde server image |
| `primary_region` | string | `us-east-1` | Primary region for server + database |
| `secondary_region` | string | `eu-west-1` | Secondary region for agents + storage |
| `enable_secondary_region` | bool | `false` | Deploy secondary region resources |
| `enable_mrap` | bool | `false` | Deploy MRAP + S3 replication |
| `enable_agents` | bool | `false` | Deploy primary region build agents |

### Environment Variables (Horde Server)

| Variable | Value | Purpose |
|----------|-------|---------|
| `Horde__http2Port` | `0` | Routes gRPC over port 443 (behind ALB) |
| `Horde__serverUrl` | `https://horde.<domain>` | External URL for presigned URL generation |
| `Horde__forceConfigUpdateOnStartup` | `true` | Re-reads globals.json on every boot |
| `Horde__Plugins__Compute__WithAws` | `true` | Enables AWS compute plugin (fleet management) |

### globals.json Storage Configuration

Configure the MRAP ARN as the storage backend:

```json
{
  "plugins": {
    "storage": {
      "backends": [
        {
          "id": "default-backend",
          "type": "Aws",
          "awsBucketName": "arn:aws:s3::<account-id>:accesspoint/<mrap-alias>.mrap",
          "awsRegion": "us-east-1"
        }
      ],
      "namespaces": [
        {"id": "default", "backend": "default-backend"},
        {"id": "horde-artifacts", "prefix": "Artifacts/", "backend": "default-backend"},
        {"id": "horde-tools", "prefix": "Tools/", "backend": "default-backend"},
        {"id": "horde-logs", "prefix": "Logs/", "backend": "default-backend"}
      ]
    }
  }
}
```

The MRAP ARN is output by Terraform as `mrap_arn` after Phase 2.

## Validation

### Server Health

```bash
curl -s https://horde.example.com/api/v1/server/info | jq .
# Expected: {"apiVersion":"...","serverVersion":"..."}
```

### Agent Connectivity

```bash
curl -s https://horde.example.com/api/v1/agents | jq '.[].name'
# Expected: agent hostnames from both regions
```

### MRAP Routing

Upload a test object and verify it lands in the nearest bucket:

```bash
# From a host in us-east-1
aws s3api put-object \
  --bucket "arn:aws:s3::<account>:accesspoint/<mrap-alias>.mrap" \
  --key test/routing-check.txt \
  --body /dev/stdin <<< "hello from us-east-1"

# Verify it's in the us-east-1 bucket
aws s3api head-object --bucket horde-artifacts-us-east-1-<account> --key test/routing-check.txt

# After ~1 second, verify CRR replicated it to eu-west-1
aws s3api head-object --bucket horde-artifacts-eu-west-1-<account> --key test/routing-check.txt --region eu-west-1
```

### End-to-End Build Test

1. Trigger a build job targeting the EU pool
2. Verify the job executes on an EU agent (check agent name in job details)
3. Verify the artifact is accessible from both regions via MRAP presigned URLs

## Cost Considerations

### Primary Cost Drivers

| Component | Approximate Monthly Cost | Notes |
|-----------|--------------------------|-------|
| DocumentDB (db.r6g.large) | ~$280 | Single instance, always-on |
| ElastiCache (cache.t3.medium) | ~$50 | Valkey/Redis, single node |
| NAT Gateway (per region) | ~$32 + $0.045/GB | Required for private subnet agents |
| S3 Cross-Region Replication | $0.02/GB transferred | Both directions |
| EC2 Agents (c6a.large) | ~$62/instance/month | Scale to 0 when idle |
| ALB | ~$16 + usage | External load balancer |

### Cost Optimization

- **Scale agents to zero** when not building (ASG `min_size=0`)
- **Selective replication:** Use S3 replication rules with tag filters to replicate only shared artifacts, not intermediate build outputs
- **Lifecycle rules:** Expire non-current S3 object versions (required for CRR but increases storage)
- **Reserved capacity:** Use Savings Plans for DocumentDB and always-on EC2 instances in production

## Known Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| Agent tool upload required on fresh deploy | Agents won't start until the tool package is available on the server | Upload manually via API (see Post-Deployment Steps) |
| No automatic preflight region routing | Users must explicitly select target region in job templates | Future: derive region from user OIDC claims or P4 edge identity |
| No VPC peering between regions | EU agents connect to US server over public internet (TLS + auth) | Add VPC peering or Transit Gateway for production |
| Single point of failure | If us-east-1 Horde server is down, all regions stop | Acceptable for PoC; add HA for production |
| S3 CRR is eventual | Sub-second for small objects, seconds for large | Consumers may need to retry if accessing just-written cross-region artifacts |

## Troubleshooting

### ECS Service Timeout (20 minutes)

**Symptom:** `terraform apply` fails after 20 minutes with:
```
Error: waiting for ECS Service update: timeout while waiting for state to become 'tfSTABLE'
```

**Cause:** The ECS service takes longer than 20 minutes to reach steady state. This often happens on Phase 2 (MRAP enable) when the task definition changes trigger a full service replacement.

**Fix:** The service is likely running fine — Terraform just timed out waiting. Run:
```bash
# Check if the service is actually healthy
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --region us-east-1 \
    --query 'TargetGroups[?contains(TargetGroupName, `ext-api`)].TargetGroupArn' --output text) \
  --region us-east-1 --query 'TargetHealthDescriptions[*].TargetHealth.State'

# If healthy, just re-run apply to sync state:
terraform apply [same vars as before]
```

If the service is NOT healthy, check CloudWatch logs:
```bash
aws logs tail cgd-unreal-horde-log-group --region us-east-1 --since 5m --format short
```

### Agent Not Appearing in Dashboard

**Symptom:** Agent instance is running (ASG shows InService) but doesn't appear in the Horde dashboard under Agents.

**Cause:** The agent needs a registration token on first connection. The CGD module's SSM/Ansible bootstrap handles this, but may take 3-5 minutes to complete. For manually provisioned agents:

```bash
# Get a registration token
curl -sk https://horde.<domain>/api/v1/admin/registrationtoken

# Configure the agent with the token
dotnet HordeAgent.dll SetServer -Name=Default -Url=https://horde.<domain> -Token=<token> -Default
```

### Container Crash: AwsCloudWatchMultiplexer

**Symptom:** ECS task keeps restarting. CloudWatch logs show:
```
System.ArgumentException: At least one client must be specified (Parameter 'clients')
   at HordeServer.Aws.AwsCloudWatchMultiplexer
```

**Cause:** `Compute.WithAws=true` requires at least one CloudWatch region configured.

**Fix:** Ensure this environment variable is set in the ECS task:
```
Horde__Compute__AwsCloudWatchRegions__0=us-east-1
```

This is already configured in the example's `extra_environment` block.

### Credentials Expire During Apply

**Symptom:** Apply succeeds for 15+ minutes then fails with `ExpiredTokenException`.

**Cause:** Session-based AWS credentials (SSO, Isengard) expire before the 20-minute ECS wait completes.

**Fix:** Use longer-lived credentials for the initial deployment, or increase session duration. After the first successful deploy, subsequent applies are much faster.

## Clean Up

```bash
# 1. Empty versioned S3 buckets (required before destroy)
aws s3api list-object-versions --bucket horde-artifacts-us-east-1-<account> \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json | \
  aws s3api delete-objects --bucket horde-artifacts-us-east-1-<account> --delete file:///dev/stdin

aws s3api list-object-versions --bucket horde-artifacts-eu-west-1-<account> --region eu-west-1 \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json | \
  aws s3api delete-objects --bucket horde-artifacts-eu-west-1-<account> --delete file:///dev/stdin --region eu-west-1

# 2. Destroy all infrastructure
terraform destroy \
  -var="image=<account-id>.dkr.ecr.us-east-1.amazonaws.com/horde-server:multi-region" \
  -var="root_domain_name=example.com" \
  -var="enable_agents=true" \
  -var="enable_mrap=true" \
  -var="enable_secondary_region=true"
```

> **Important:** Terraform cannot delete non-empty versioned S3 buckets. You must empty them first (step 1) or the destroy will fail on those resources.
