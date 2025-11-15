# DDC-Infra Tidy Plan - CORRECTED

## Current State
- ✅ **CLEAN TERRAFORM PLAN**: "No changes. Your infrastructure matches the configuration."
- ✅ **DEPLOYED INFRASTRUCTURE**: All resources currently deployed and working
- ✅ **GOAL**: Maintain clean plan after reorganization

## COMPLETE RESOURCE INVENTORY

### **data.tf** (4 resources) ✅ CORRECT
- `data.aws_caller_identity.current`
- `data.aws_vpc.main`
- `data.aws_ami.scylla_ami`
- `data.aws_ami.amazon_linux`

### **eksaddons.tf** (8 resources) - IAM + EKS Addons
- `null_resource.cleanup_orphaned_dns_records`
- `aws_iam_role.external_dns` ❌ **MOVE TO iam.tf**
- `aws_iam_role_policy.external_dns` ❌ **MOVE TO iam.tf**
- `aws_eks_addon.external_dns`
- `data.aws_route53_zone.user_provided` ❌ **MOVE TO data.tf**
- `data.aws_eks_addon_version.external_dns` ✅ **KEEP HERE**
- `data.aws_eks_addon_version.fluent_bit` ✅ **KEEP HERE**
- `aws_eks_addon.fluent_bit`

### **iam.tf** (21 resources) - Already has most IAM
- ScyllaDB IAM (3 resources)
- OIDC Provider + TLS cert (2 resources)
- DDC Service Account IAM (3 resources)
- FluentBit IAM (3 resources)
- AWS Load Balancer Controller IAM (5 resources)
- Cert Manager IAM (3 resources)
- Policy documents (2 resources)

### **main.tf** (28 resources) ❌ **HEAVILY MIXED**
**Security Group Resources (6):**
- `aws_security_group.cluster_security_group` ❌ **MOVE TO sg.tf**
- `aws_vpc_security_group_ingress_rule.cluster_self` ❌ **MOVE TO sg.tf**
- `aws_vpc_security_group_ingress_rule.cluster_kubelet` ❌ **MOVE TO sg.tf**
- `aws_vpc_security_group_ingress_rule.cluster_https` ❌ **MOVE TO sg.tf**
- `aws_vpc_security_group_ingress_rule.cluster_dns` ❌ **MOVE TO sg.tf**
- `aws_vpc_security_group_egress_rule.cluster_egress` ❌ **MOVE TO sg.tf**

**EKS Core Resources (4):** ✅ **KEEP HERE**
- `aws_eks_cluster.unreal_cloud_ddc_eks_cluster`
- `aws_eks_access_entry.additional`
- `aws_eks_access_policy_association.additional`
- `null_resource.ddc_nodepool`

**Helm Installations (3):** ✅ **KEEP HERE**
- `null_resource.aws_load_balancer_controller_crds`
- `null_resource.aws_load_balancer_controller`
- `null_resource.cert_manager`

**CloudWatch (1):** ✅ **KEEP HERE**
- `aws_cloudwatch_log_group.unreal_cluster_cloudwatch`

**EKS Cluster IAM (9):** ❌ **MOVE TO iam.tf**
- `aws_iam_role.eks_cluster_role`
- `aws_iam_role_policy_attachment.eks_cluster_policy`
- `aws_iam_role_policy_attachment.eks_compute_policy`
- `aws_iam_role_policy_attachment.eks_block_storage_policy`
- `aws_iam_role_policy_attachment.eks_load_balancing_policy`
- `aws_iam_role_policy_attachment.eks_networking_policy`
- `data.aws_iam_policy_document.eks_cluster_custom_tags`
- `aws_iam_policy.eks_cluster_custom_tags`
- `aws_iam_role_policy_attachment.eks_cluster_custom_tags`

**EKS Node IAM (6):** ❌ **MOVE TO iam.tf**
- `aws_iam_role.eks_node_role`
- `aws_iam_role_policy_attachment.eks_node_worker_policy`
- `aws_iam_role_policy_attachment.eks_node_ecr_policy`
- `aws_iam_role_policy_attachment.eks_worker_node_policy`
- `aws_iam_role_policy_attachment.eks_cni_policy`
- `aws_iam_role_policy_attachment.eks_container_registry_policy`

### **scylla.tf** (3 resources)
- `aws_iam_instance_profile.scylla_instance_profile` ❌ **MOVE TO iam.tf**
- `aws_instance.scylla_ec2_instance_seed`
- `aws_instance.scylla_ec2_instance_other_nodes`

### **sg.tf** (6 resources) - Has ScyllaDB SGs + 1 cluster reference
- `aws_security_group.scylla_security_group`
- `aws_vpc_security_group_egress_rule.ssm_egress_sg_rules`
- `aws_vpc_security_group_ingress_rule.self_ingress_sg_rules`
- `aws_vpc_security_group_ingress_rule.scylla_from_vpc_cql`
- `aws_vpc_security_group_egress_rule.self_scylla_egress_sg_rules`
- `aws_vpc_security_group_ingress_rule.cluster_additional_eks_sg_ingress_rule` ⚠️ **DEPENDS ON CLUSTER SG**

## CRITICAL DEPENDENCY RISKS

### **🔥 HIGH RISK: Circular Dependencies**
1. **sg.tf references cluster SG from main.tf**:
   - `cluster_additional_eks_sg_ingress_rule` uses `aws_security_group.cluster_security_group.id`
2. **Multiple IAM cross-references**:
   - EKS cluster uses node role ARN
   - Helm installations depend on IAM roles
   - OIDC provider used by multiple IRSA roles

### **⚠️ MEDIUM RISK: Complex IAM Dependencies**
- 15 IAM resources in main.tf need coordinated move
- External-DNS IAM in eksaddons.tf references OIDC provider in iam.tf
- ScyllaDB instance profile in scylla.tf references role in iam.tf

## REVISED REORGANIZATION PLAN

### **PHASE 1: Data Sources (Low Risk)**
- [ ] **Task 1.1**: Move `data.aws_route53_zone.user_provided` from eksaddons.tf → data.tf
- [ ] **Task 1.2**: Verify terraform plan clean

### **PHASE 2: IAM Consolidation (High Risk - Multiple Steps)**
- [ ] **Task 2.1**: Move External-DNS IAM from eksaddons.tf → iam.tf
- [ ] **Task 2.2**: Verify terraform plan clean
- [ ] **Task 2.3**: Move ScyllaDB instance profile from scylla.tf → iam.tf
- [ ] **Task 2.4**: Verify terraform plan clean
- [ ] **Task 2.5**: Move EKS cluster IAM (9 resources) from main.tf → iam.tf
- [ ] **Task 2.6**: Verify terraform plan clean
- [ ] **Task 2.7**: Move EKS node IAM (6 resources) from main.tf → iam.tf
- [ ] **Task 2.8**: Verify terraform plan clean

### **PHASE 3: Security Groups (High Risk - Dependency Order)**
- [ ] **Task 3.1**: Move cluster SG and rules (6 resources) from main.tf → sg.tf
- [ ] **Task 3.2**: Verify terraform plan clean
- [ ] **Task 3.3**: Verify cluster_additional_eks_sg_ingress_rule still works

### **PHASE 4: Final Verification**
- [ ] **Task 4.1**: Run complete terraform plan - must show "No changes"
- [ ] **Task 4.2**: Test cross-file references
- [ ] **Task 4.3**: Document final organization

## CRITICAL SAFETY RULES
- **STOP IMMEDIATELY** if any terraform plan shows changes
- **ONE RESOURCE TYPE AT A TIME**: Don't mix IAM and SG moves
- **VERIFY AFTER EACH TASK**: Run terraform plan after every move
- **NO LOGICAL NAME CHANGES**: Keep all resource names identical
- **PRESERVE ALL DEPENDENCIES**: Maintain depends_on relationships

## SUCCESS CRITERIA
- ✅ Clean terraform plan maintained throughout
- ✅ All 22 IAM resources consolidated in iam.tf
- ✅ All 12 security group resources in sg.tf
- ✅ All 5 lookup data sources in data.tf
- ✅ main.tf focused on core EKS cluster and Helm installations