# Unreal Cloud DDC Multi Region

This sample deploys [Unreal Cloud DDC](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-derived-data-cache-in-unreal-engine) (Derived Data Cache) to two AWS Regions. Each Region has its own DDC endpoint for nearby clients, and the two Regions replicate cache data to each other.

It uses three modules from this repository:

| Module | Deployed | What it creates |
|--------|----------|-----------------|
| [`vpc`](./vpc) (sample-local) | once per Region | VPC, public and private subnets, NAT gateway, S3 gateway endpoint |
| [`unreal-cloud-ddc-infra`](../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra/README.md) | once per Region | EKS cluster and node groups, ScyllaDB nodes, S3 bucket. Region 1 also gets the ScyllaDB monitoring stack and its ALB. |
| [`unreal-cloud-ddc-intra-cluster`](../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster/README.md) | once per Region | EKS add-ons, AWS Load Balancer Controller, ECR pull-through cache, and the Unreal Cloud DDC Helm release |

The sample itself adds the cross-Region pieces: VPC peering, security group rules, Route53 records, ACM certificates, a shared bearer token, and an SSM document that sets the ScyllaDB keyspace replication.

## Architecture

```text
                 clients
                    |
        <name_prefix>.<zone>  (Route53 latency record)
           /                         \
  Region 1 (regions[0])          Region 2 (regions[1])
  DDC NLB  :443 / :8443 (TLS)    DDC NLB  :443 / :8443 (TLS)
  EKS: DDC pods + worker         EKS: DDC pods + worker
  ScyllaDB x3 (seed)  <--peering-->  ScyllaDB x3
  S3 bucket                      S3 bucket
  Grafana ALB (monitoring)
```

| Component | Per Region | Default size |
|-----------|-----------|--------------|
| EKS NVMe node group (DDC pods) | 2 nodes | `i3en.xlarge` |
| EKS worker node group (replication worker) | 1 node | `c6i.large` |
| EKS system node group | 1 node | `m7i.large` |
| ScyllaDB nodes | 3 | `i4i.xlarge`, AMI `ScyllaDB 2026.3.1` |
| ScyllaDB monitoring | Region 1 only | Prometheus, Alertmanager, Grafana |

### Replication

Each Region's DDC worker replicates from the other Region's regional endpoint. The endpoint names are built from variables, so they are known at plan time. Both Regions install in a single `terraform apply`, with replication already on.

```text
region 1 worker -> https://<name_prefix>-<region 2>.<zone> -> Route53 alias -> region 2 DDC NLB
region 2 worker -> https://<name_prefix>-<region 1>.<zone> -> Route53 alias -> region 1 DDC NLB
```

A worker may log connection errors for the first few minutes, until the other Region's NLB and DNS record exist.

ScyllaDB runs as one cluster with one datacenter per Region, joined over VPC peering. After both Regions are up, an SSM document on the region 1 seed node sets the replication factor of each Region's local keyspace.

### Network access

| Path | Allowed from | Ports |
|------|--------------|-------|
| Clients to DDC NLBs and Grafana ALB | `allowed_client_cidrs`, plus your detected IP when `allow_my_ip = true` | 443, 8443 |
| Worker to the other Region's DDC NLB | the other Region's NAT gateway IP (`/32`) | 443, 8443 |
| ScyllaDB between VPCs | the other VPC's CIDR | 7000, 7001, 9042, 9142, 19042, 19142 |
| Region 1 monitoring to region 2 ScyllaDB | region 1 VPC CIDR | 9100, 9180 |
| Terraform to EKS API | `eks_public_access_cidrs` (default: your detected IP) | 443 |

All DDC traffic uses TLS. Each NLB terminates TLS with an ACM certificate for `<name_prefix>-<region>.<zone>` and `<name_prefix>.<zone>`. Port 443 serves HTTP/1.1 and port 8443 serves HTTP/2. There is no plain-HTTP listener.

### Names and DNS records

`name_prefix` (default `cgd-ddc-mr`, at most 11 characters) prefixes every name that must be unique per account and Region, or per hosted zone. This lets the sample run next to the single Region sample in the same account.

| Resource | Name |
|----------|------|
| DDC client endpoint (latency-routed to the closer Region) | `<name_prefix>.<zone>` |
| DDC regional endpoint, also the replication target | `<name_prefix>-<region>.<zone>` |
| ScyllaDB monitoring (Grafana) | `monitoring.<name_prefix>.<zone>` |
| DDC Network Load Balancer, per Region | `<name_prefix>-unreal-cloud-ddc` |
| Monitoring ALB and target group | `<name_prefix>-monitoring-alb`, `<name_prefix>-scylla-monitoring-tg` |
| EKS clusters | `cgd-unreal-cloud-ddc-cluster-<region>` |

`<zone>` is `route53_public_hosted_zone_name`.

## Prerequisites

- Terraform `>= 1.10.3`, AWS CLI v2, `kubectl`, and `curl`
- AWS credentials for the target account that stay valid for the whole apply (about 30 minutes)
- A Route53 **public** hosted zone in the account
- A GitHub account with access to the [Unreal Cloud DDC image](https://github.com/orgs/EpicGames/packages/container/package/unreal-cloud-ddc). See [Epic's instructions](https://www.unrealengine.com/en-US/ue-on-github) for linking your Epic and GitHub accounts.
- One Secrets Manager secret **in each Region** with your GitHub credentials, as described below

### GitHub credentials secret

The intra-cluster module pulls the DDC image through an ECR pull-through cache, which reads GitHub credentials from Secrets Manager.

> [!IMPORTANT]
> The GitHub token must be able to pull the Unreal Cloud DDC image from `ghcr.io/epicgames`. It needs at least:
>
> - A **personal access token (classic)** with the `read:packages` scope. GitHub Packages does not accept fine-grained tokens.
> - A GitHub account that is a member of the `EpicGames` organization, which you get by [linking your Epic Games and GitHub accounts](https://www.unrealengine.com/en-US/ue-on-github).
>
> Without both, the pull-through cache can't reach the image, so ECR never creates the `github/epicgames/unreal-cloud-ddc` repository. The DDC pods then stay in `ImagePullBackOff`, and `terraform apply` times out on the DDC Helm release.

Create one secret in each Region. The name must start with `ecr-pullthroughcache/`, and the value must use this format:

```json
{
  "username": "GITHUB-USER-NAME-PLACEHOLDER",
  "accessToken": "GITHUB-ACCESS-TOKEN-PLACEHOLDER"
}
```

```bash
for r in us-west-2 us-east-2; do
  aws secretsmanager create-secret --region "$r" \
    --name ecr-pullthroughcache/github-unreal-cloud-ddc \
    --secret-string file://github-credentials.json
done
```

## Deployment

### 1. Set your variables

Create `terraform.tfvars` in this directory:

```hcl
regions                         = ["us-west-2", "us-east-2"]
github_credential_arn_region_1  = "arn:aws:secretsmanager:us-west-2:<account>:secret:ecr-pullthroughcache/<name>"
github_credential_arn_region_2  = "arn:aws:secretsmanager:us-east-2:<account>:secret:ecr-pullthroughcache/<name>"
route53_public_hosted_zone_name = "example.com"
```

Each secret ARN must be in the Region it is used for. Optional variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `name_prefix` | `cgd-ddc-mr` | Prefix for load balancer and DNS names. See [Names and DNS records](#names-and-dns-records). |
| `allow_my_ip` | `true` | Allow your detected public IP to reach the DDC and monitoring load balancers |
| `allowed_client_cidrs` | `[]` | More CIDRs allowed to reach the DDC and monitoring load balancers |
| `eks_public_access` | `true` | Keep the EKS public API endpoints open |
| `eks_public_access_cidrs` | detected IP `/32` | CIDRs allowed on the EKS public API endpoints |
| `ebs_csi_use_pod_identity` | `true` | Use EKS Pod Identity (or IRSA when `false`) for the EBS CSI driver |

### 2. Make sure Terraform can reach the EKS API

Terraform installs Helm charts and add-ons through each cluster's public API endpoint, so the host running Terraform must match `eks_public_access_cidrs`. The default is the single IP that `checkip.amazonaws.com` reports, which works for a host with one stable public IP.

If your host's egress comes from several IPs (NAT pool, VPN, CI), list all of them:

```hcl
eks_public_access_cidrs = ["<YOUR-IP-ADDRESS>"]
allowed_client_cidrs    = ["<YOUR-IP-ADDRESS>"]
```

`checkip.amazonaws.com` may not show the IP your host uses to reach AWS. If the apply fails with `Kubernetes cluster unreachable ... i/o timeout`, read the `sourceIPAddress` of your recent EKS calls in CloudTrail and add that range.

With `eks_public_access = false` the API endpoints are private, and Terraform must run from inside the VPCs (for example a bastion or an in-VPC CI runner).

### 3. Deploy

```bash
terraform init
terraform apply
```

The apply takes about 30 minutes:

| Phase | Time |
|-------|------|
| VPCs, EKS clusters and node groups, ScyllaDB | 20-25 minutes |
| EKS add-ons, Helm releases, load balancers, DNS, certificates | 5-10 minutes |

### 4. Verify

Each Region's health endpoint should return `200` and `Healthy`:

```bash
curl -i https://<name_prefix>-us-west-2.<zone>/health/live
curl -i https://<name_prefix>-us-east-2.<zone>/health/live
```

Then write a test blob to a Region and read it back:

```bash
assets/sanity_check.sh <name_prefix>-us-west-2.<zone>
```

The script reads the bearer token from Secrets Manager, does a `PUT` and a `GET`, compares the bytes, and exits non-zero on any failure. Run it with no argument to test the latency-routed client endpoint.

## Using the deployment

### Endpoints and outputs

| Output | Value |
|--------|-------|
| `unreal_ddc_url` | Client endpoint, `<name_prefix>.<zone>` |
| `monitoring_url` | Grafana, `monitoring.<name_prefix>.<zone>` |
| `unreal_cloud_ddc_bearer_token_arn` | Secrets Manager ARN of the bearer token (replicated to region 2) |
| `scylla_ips`, `scylla_ips_by_region` | Private IPs of the ScyllaDB nodes |

Point Unreal Engine clients at `https://<name_prefix>.<zone>`. Route53 sends each client to the closer Region.

### Calling the API

```bash
TOKEN=$(aws secretsmanager get-secret-value --secret-id "$(terraform output -raw unreal_cloud_ddc_bearer_token_arn)" --query SecretString --output text)

# Put a 4-byte blob ("test")
curl -i https://<name_prefix>.<zone>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa \
  -X PUT --data 'test' \
  -H 'content-type: application/octet-stream' \
  -H 'X-Jupiter-IoHash: 4878CA0425C739FA427F7EDA20FE845F6B2E46BA' \
  -H "Authorization: ServiceAccount $TOKEN"
# Expect: HTTP/1.1 200 OK and {"needs":[]}

# Read it back
curl -i https://<name_prefix>.<zone>/api/v1/refs/ddc/default/00000000000000000000000000000000000000aa.json \
  -H "Authorization: ServiceAccount $TOKEN"
# Expect: HTTP/1.1 200 OK and {"RawHash":"4878ca04...","RawSize":4}
```

The bearer token only has access to the `ddc` namespace.

For load testing, use Epic's [benchmarking tools](https://github.com/EpicGames/UnrealEngine/tree/release/Engine/Source/Programs/UnrealCloudDDC/Benchmarks). We used an `x2idn.32xlarge`, which matches Epic's benchmarking instance:

```bash
docker run --network host jupiter_benchmark --seed --seed-remote --host https://<name_prefix>.<zone> --namespace ddc \
  --header="Authorization: ServiceAccount $TOKEN" all
```

### ScyllaDB monitoring

Region 1 runs the [ScyllaDB Monitoring Stack](https://monitoring.docs.scylladb.com/) (Prometheus, Alertmanager and Grafana), which scrapes the ScyllaDB nodes in both Regions. Open `https://` followed by the `monitoring_url` output. The Overview dashboard has one section per Region (datacenter).

### Production considerations

- The bearer token is a shared service account for testing. For production, switch DDC to bearer authentication with your identity provider.
- Keep `allowed_client_cidrs` and `eks_public_access_cidrs` as narrow as possible, or close the EKS public endpoints and run Terraform from inside the VPCs.

## Configuration notes

### EBS CSI driver identity

The EBS CSI driver in each Region needs AWS credentials to manage EBS volumes. `ebs_csi_use_pod_identity` selects how it gets them:

- **EKS Pod Identity (default, `true`).** Uses `eks-auth:AssumeRoleForPodIdentity` and installs the `eks-pod-identity-agent` add-on. It also works in accounts whose AWS Organizations SCP or RCP denies `sts:AssumeRoleWithWebIdentity`.
- **IRSA (`false`).** Uses IAM Roles for Service Accounts through the cluster OIDC provider. Use it where Pod Identity is not available, for example Fargate or Windows nodes.

### ScyllaDB datacenter names

ScyllaDB fails to parse datacenter names that end in `-1`, so the sample removes that suffix. Other suffixes are kept, and any Regions work.

| Region | Datacenter name |
|--------|-----------------|
| `us-east-1` | `us-east` |
| `us-east-2` | `us-east-2` |
| `us-west-2` | `us-west-2` |
| `eu-west-1` | `eu-west` |

## Troubleshooting

### Connect kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name cgd-unreal-cloud-ddc-cluster-us-west-2
kubectl get pods -n unreal-cloud-ddc                 # all pods should be Running
kubectl get svc -n unreal-cloud-ddc                  # EXTERNAL-IP is the NLB hostname
kubectl logs -n unreal-cloud-ddc -l app.kubernetes.io/name=unreal-cloud-ddc --tail=50
helm status unreal-cloud-ddc-initialize -n unreal-cloud-ddc
```

Repeat for region 2 with its Region and cluster name.

### Common issues

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Kubernetes cluster unreachable ... i/o timeout` | Your host's real egress IP is not in `eks_public_access_cidrs` | See [step 2](#2-make-sure-terraform-can-reach-the-eks-api) |
| `curl` to the DDC endpoint times out | Your IP is not in `allowed_client_cidrs`, or latency routing sent you to the other Region | Add your IP range, or call `<name_prefix>-<region>.<zone>` directly |
| DDC pods in `ImagePullBackOff` | The GitHub token can't pull from `ghcr.io/epicgames` | See [GitHub credentials secret](#github-credentials-secret) |
| Helm release times out after 15 minutes | Pods can't start, or the NLB can't be created | Check pods and Service events. `DuplicateLoadBalancerName` means another deployment in the account and Region uses the same `name_prefix`. |
| Pods in `CrashLoopBackOff` with `Unrecognized strategy option {us-east-1}` | Datacenter name mismatch | See [ScyllaDB datacenter names](#scylladb-datacenter-names) |
| EBS CSI add-on stuck in `CREATING` | IRSA blocked by an SCP or RCP | Use `ebs_csi_use_pod_identity = true` |
| SSM association failed | Keyspace replication not set | Check the `update_keyspaces_document` run output in SSM, then re-run the association |

To check ScyllaDB datacenters from a ScyllaDB node (connect with SSM Session Manager):

```bash
cqlsh -e "SELECT data_center FROM system.local; SELECT data_center FROM system.peers;"
cqlsh -e "DESCRIBE KEYSPACE jupiter;"
```

## Deletion

Destroy the Kubernetes resources first, so the AWS Load Balancer Controller removes the NLBs it created:

```bash
terraform destroy -target module.unreal_cloud_ddc_intra_cluster_region_1 -target module.unreal_cloud_ddc_intra_cluster_region_2
```

If this fails with `context deadline exceeded`, run it again. Then destroy everything else:

```bash
terraform destroy
```

Terraform must still reach the EKS API during the first command, so keep your IP in `eks_public_access_cidrs`. If a VPC or internet gateway can't be deleted with `DependencyViolation`, delete any leftover `<name_prefix>-unreal-cloud-ddc` NLB and `k8s-*` target groups in that VPC, then run `terraform destroy` again.

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=6.73.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.26.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 2.17.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.5 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.24.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >=3.2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >=3.5.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >=6.73.0 |
| <a name="provider_aws.region-1"></a> [aws.region-1](#provider\_aws.region-1) | >=6.73.0 |
| <a name="provider_awscc.region-1"></a> [awscc.region-1](#provider\_awscc.region-1) | >= 1.26.0 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.4.5 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_unreal_cloud_ddc_infra_region_1"></a> [unreal\_cloud\_ddc\_infra\_region\_1](#module\_unreal\_cloud\_ddc\_infra\_region\_1) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra | n/a |
| <a name="module_unreal_cloud_ddc_infra_region_2"></a> [unreal\_cloud\_ddc\_infra\_region\_2](#module\_unreal\_cloud\_ddc\_infra\_region\_2) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-infra | n/a |
| <a name="module_unreal_cloud_ddc_intra_cluster_region_1"></a> [unreal\_cloud\_ddc\_intra\_cluster\_region\_1](#module\_unreal\_cloud\_ddc\_intra\_cluster\_region\_1) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster | n/a |
| <a name="module_unreal_cloud_ddc_intra_cluster_region_2"></a> [unreal\_cloud\_ddc\_intra\_cluster\_region\_2](#module\_unreal\_cloud\_ddc\_intra\_cluster\_region\_2) | ../../modules/unreal/unreal-cloud-ddc/unreal-cloud-ddc-intra-cluster | n/a |
| <a name="module_unreal_cloud_ddc_vpc_region_1"></a> [unreal\_cloud\_ddc\_vpc\_region\_1](#module\_unreal\_cloud\_ddc\_vpc\_region\_1) | ./vpc | n/a |
| <a name="module_unreal_cloud_ddc_vpc_region_2"></a> [unreal\_cloud\_ddc\_vpc\_region\_2](#module\_unreal\_cloud\_ddc\_vpc\_region\_2) | ./vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.unreal_cloud_ddc_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.unreal_cloud_ddc_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_acm_certificate_validation.unreal_cloud_ddc_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_acm_certificate_validation.unreal_cloud_ddc_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route.vpc_region_1_to_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.vpc_region_2_to_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_record.scylla_monitoring_cert_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.scylla_monitoring_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_regional_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.unreal_cloud_ddc_regional_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.unreal_ddc_load_balancer_access_security_group_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.unreal_ddc_load_balancer_access_security_group_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_association.unreal_cloud_ddc_scylla_db_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_association) | resource |
| [aws_ssm_document.unreal_cloud_ddc_scylla_update_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_vpc_peering_connection.vpc_connection_region_1_to_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection) | resource |
| [aws_vpc_peering_connection_accepter.region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_accepter) | resource |
| [aws_vpc_peering_connection_options.accepter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_options) | resource |
| [aws_vpc_peering_connection_options.requester](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_peering_connection_options) | resource |
| [aws_vpc_security_group_egress_rule.unreal_ddc_load_balancer_egress_sg_rules_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.unreal_ddc_load_balancer_egress_sg_rules_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_db_region_1_to_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.scylla_db_region_2_to_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_1_to_lb_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_1_to_lb_region_2_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_2_to_lb_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_cluster_region_2_to_lb_region_1_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_region_1_nat_to_lb_region_2_443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_region_1_nat_to_lb_region_2_8443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_region_2_nat_to_lb_region_1_443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_cloud_ddc_region_2_nat_to_lb_region_1_8443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http2_ingress_rule_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_http2_ingress_rule_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_https_ingress_rule_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.unreal_ddc_load_balancer_https_ingress_rule_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [awscc_secretsmanager_secret.unreal_cloud_ddc_token](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_availability_zones.available_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_availability_zones.available_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecr_authorization_token.token_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_ecr_authorization_token.token_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token) | data source |
| [aws_region.region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_region.region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.root](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [aws_secretsmanager_secret_version.unreal_cloud_ddc_token_region_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [http_http.public_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_github_credential_arn_region_1"></a> [github\_credential\_arn\_region\_1](#input\_github\_credential\_arn\_region\_1) | ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub | `string` | n/a | yes |
| <a name="input_github_credential_arn_region_2"></a> [github\_credential\_arn\_region\_2](#input\_github\_credential\_arn\_region\_2) | ARN of the secret in AWS Secrets Manager corresponding to your GitHub credentials (username and accessToken). This is used to allow access to the Unreal Cloud DDC repository in GitHub | `string` | n/a | yes |
| <a name="input_route53_public_hosted_zone_name"></a> [route53\_public\_hosted\_zone\_name](#input\_route53\_public\_hosted\_zone\_name) | The root domain name for the Hosted Zone where the ScyllaDB monitoring record should be created. | `string` | n/a | yes |
| <a name="input_allow_my_ip"></a> [allow\_my\_ip](#input\_allow\_my\_ip) | Automatically add your IP to the security groups allowing access to the Unreal DDC and SycllaDB Monitoring load balancers | `bool` | `true` | no |
| <a name="input_allowed_client_cidrs"></a> [allowed\_client\_cidrs](#input\_allowed\_client\_cidrs) | CIDR blocks allowed to reach the DDC NLBs and the monitoring ALB on ports 80, 443 and 8080 in both regions. Added to your auto-detected IP when allow\_my\_ip is true. Set this when your egress comes from several IPs (NAT pool, VPN), for example ["203.0.113.10/32", "203.0.113.11/32"]. | `list(string)` | `[]` | no |
| <a name="input_ebs_csi_use_pod_identity"></a> [ebs\_csi\_use\_pod\_identity](#input\_ebs\_csi\_use\_pod\_identity) | Use EKS Pod Identity (true, the default) instead of IRSA (false) for the EBS<br/>CSI driver in both regions. Pod Identity is the AWS-recommended mechanism and<br/>also works in accounts whose Organization SCP/RCP denies<br/>sts:AssumeRoleWithWebIdentity. Set to false for the legacy IRSA path (for<br/>example Fargate or Windows nodes). | `bool` | `true` | no |
| <a name="input_eks_public_access"></a> [eks\_public\_access](#input\_eks\_public\_access) | Whether the public API endpoint of both EKS clusters is enabled. Defaults to<br/>true so a first apply from a laptop works without extra setup. Set to false<br/>to close the public endpoints entirely; Terraform must then run from inside<br/>the VPCs (for example from a bastion or in-VPC CI runner).<br/>eks\_public\_access\_cidrs is ignored when this is false. | `bool` | `true` | no |
| <a name="input_eks_public_access_cidrs"></a> [eks\_public\_access\_cidrs](#input\_eks\_public\_access\_cidrs) | CIDR blocks allowed to reach the EKS public API endpoints. When left empty,<br/>the sample auto-detects the caller's public IP (via checkip) and uses that<br/>/32. That only works reliably when your egress is a single, stable public<br/>IP. Behind a NAT pool, corporate VPN or CI, set this explicitly to your<br/>egress CIDR(s). | `list(string)` | `[]` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for names that must be unique per account and region or per hosted zone: the DDC NLBs, the monitoring ALB and target group, and the DNS names (<prefix>.<zone>, <prefix>-<region>.<zone>, monitoring.<prefix>.<zone>). Lets this sample run next to the single region sample. At most 11 characters. | `string` | `"cgd-ddc-mr"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | List of regions to deploy the solution | `list(string)` | <pre>[<br/>  "us-west-2",<br/>  "us-east-2"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_monitoring_url"></a> [monitoring\_url](#output\_monitoring\_url) | Route53 DNS name of the ScyllaDB monitoring stack (Grafana), served over HTTPS from region 1. |
| <a name="output_scylla_ips"></a> [scylla\_ips](#output\_scylla\_ips) | n/a |
| <a name="output_scylla_ips_by_region"></a> [scylla\_ips\_by\_region](#output\_scylla\_ips\_by\_region) | n/a |
| <a name="output_unreal_cloud_ddc_bearer_token_arn"></a> [unreal\_cloud\_ddc\_bearer\_token\_arn](#output\_unreal\_cloud\_ddc\_bearer\_token\_arn) | n/a |
| <a name="output_unreal_ddc_url"></a> [unreal\_ddc\_url](#output\_unreal\_ddc\_url) | Latency-routed DDC client endpoint (Route53 record name). |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->
