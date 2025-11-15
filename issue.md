### Community Note

* Please vote on this issue by adding a 👍 [reaction](https://blog.github.com/2016-03-10-add-reactions-to-pull-requests-issues-and-comments/) to the original issue to help the community and maintainers prioritize this request
* Please do not leave "+1" or other comments that do not add relevant new information or questions, they generate extra noise for issue followers and do not help prioritize the request
* If you are interested in working on this issue or have submitted a pull request, please leave a comment
* The resources and data sources in this provider are generated from the CloudFormation schema, so they can only support the actions that the underlying schema supports. For this reason submitted bugs should be limited to defects in the generation and runtime code of the provider. Customizing behavior of the resource, or noting a gap in behavior are not valid bugs and should be submitted as enhancements to AWS via the CloudFormation Open Coverage Roadmap.

### Terraform CLI and Terraform AWS Cloud Control Provider Version

```
Terraform >= 1.11
+ provider registry.terraform.io/hashicorp/awscc >= 1.26.0
```

### Affected Resource(s)

* awscc_eks_cluster

### Terraform Configuration Files

```hcl
resource "awscc_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  name     = "test-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"

  bootstrap_self_managed_addons = false

  resources_vpc_config = {
    subnet_ids              = ["subnet-12345", "subnet-67890"]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.cluster_security_group.id]
  }

  access_config = {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  compute_config = {
    enabled       = true
    node_role_arn = aws_iam_role.eks_node_role.arn
  }

  kubernetes_network_config = {
    elastic_load_balancing = {
      enabled = true
    }
  }

  storage_config = {
    block_storage = {
      enabled = true
    }
  }

  tags = [
    {
      key   = "Environment"
      value = "test"
    }
  ]
}
```

### Debug Output

[Link to GitHub Gist with debug output](https://gist.github.com/novekm/3c1546ce7adb2c6994ff660c29663f68)

**Key findings from debug output:**
- AWSCC provider v1.63.0 starts correctly during validation phase
- Provider exits unexpectedly during validation: `provider.stdio: received EOF, stopping recv loop`
- Provider process exits with: `plugin process exited: plugin=.terraform/providers/registry.terraform.io/hashicorp/awscc/1.63.0`
- This occurs before the planning phase, suggesting the provider cannot validate EKS Auto Mode configuration
- Standard AWS provider works fine with equivalent EKS Auto Mode configuration

**Key findings from debug output:**
- AWSCC provider v1.63.0 starts successfully
- EKS cluster resource references are properly configured
- Provider exits unexpectedly during validation/planning phase
- No specific error message from AWSCC provider before exit

### Panic Output

N/A - No panic, but provider error

### Expected Behavior

The awscc_eks_cluster resource should:
1. Actually create the EKS cluster in AWS when terraform apply succeeds
2. Be readable and manageable through Terraform operations (plan, apply, refresh, destroy) without provider errors
3. Maintain accurate state between Terraform and AWS

### Actual Behavior

**CRITICAL PROVIDER CRASH BUG:**

1. **Provider crashes during terraform apply** - Debug logs show provider process exit
2. **Resource never added to Terraform state** - No awscc_eks_cluster in state file
3. **NO CLUSTER EXISTS IN AWS** - Confirmed via AWS Console and CLI
4. **Subsequent operations fail** because Terraform config references non-existent resource:

```
Warning: AWS Resource Not Found During Refresh

  with awscc_eks_cluster.unreal_cloud_ddc_eks_cluster,
  on eks.tf line 94, in resource "awscc_eks_cluster" "unreal_cloud_ddc_eks_cluster":
  94: resource "awscc_eks_cluster" "unreal_cloud_ddc_eks_cluster" {

Automatically removing from Terraform State instead of returning the error, which may trigger resource recreation. Original Error: couldn't find resource

Error: Missing Resource Identity After Read

  with awscc_eks_cluster.unreal_cloud_ddc_eks_cluster,
  on eks.tf line 94, in resource "awscc_eks_cluster" "unreal_cloud_ddc_eks_cluster":
  94: resource "awscc_eks_cluster" "unreal_cloud_ddc_eks_cluster" {

The Terraform Provider unexpectedly returned no resource identity data after having no errors in the resource read. This is always an issue in the Terraform Provider and should be reported to the provider developers.
```

### Steps to Reproduce

1. Run `terraform apply` with awscc_eks_cluster resource for EKS Auto Mode
2. **Provider crashes during creation** - Debug logs show provider process exit
3. **Resource never created in AWS** - No cluster exists
4. **Resource never added to state** - State file contains no awscc_eks_cluster resource
5. Run `terraform plan` or `terraform refresh`
6. **Terraform tries to refresh non-existent resource** from configuration
7. Provider fails because resource was never successfully created
8. **Configuration references resource that provider failed to create**

### Important Factoids

- **CRITICAL**: This occurs specifically with EKS Auto Mode clusters (compute_config.enabled = true)
- **CRITICAL**: Provider crashes during cluster creation without proper error reporting
- **CRITICAL**: Resource never added to Terraform state due to provider crash
- **CONFIRMED**: AWS Console shows no cluster was created
- **CONFIRMED**: AWS CLI confirms no cluster exists (`aws eks list-clusters`)
- **CONFIRMED**: Terraform state file contains NO awscc_eks_cluster resource (creation failed)
- **CONFIRMED**: This prevents proper resource lifecycle management
- **CONFIRMED**: Standard AWS provider works correctly with equivalent configuration (using vpc_config instead of resources_vpc_config)
- **ROOT CAUSE**: AWSCC provider crashes during EKS Auto Mode validation/creation phase

### References

- **CRITICAL RELIABILITY BUG**: AWSCC provider v1.63.0 has broken EKS Auto Mode cluster creation
- **PROVIDER CRASH**: Provider exits unexpectedly during EKS Auto Mode cluster creation
- **INCOMPLETE CREATION**: Resource never added to state due to provider failure
- **CONFIRMED IMPACT**: Makes AWSCC provider completely unreliable for EKS Auto Mode clusters
- **EVIDENCE**: Terraform state analysis confirms no awscc_eks_cluster resource exists (creation never completed)
- **WORKAROUND**: Use standard AWS provider with equivalent configuration until this is fixed
- **SEVERITY**: Provider crashes prevent EKS Auto Mode cluster creation entirely