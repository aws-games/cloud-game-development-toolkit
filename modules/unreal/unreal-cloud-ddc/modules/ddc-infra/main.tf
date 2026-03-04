################################################################################
# EKS Cluster (Foundation)
################################################################################

resource "aws_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  name     = local.name_prefix
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  # CRITICAL: Must be false for EKS Auto Mode
  # AWS's confusing naming: "bootstrap_self_managed_addons = false" means:
  # "Don't let me manage the BOOTSTRAP addons (vpc-cni, coredns, kube-proxy, EBS CSI)"
  # EKS Auto Mode integrates these as built-in core components, NOT separate addons
  # You can still install OTHER addons (External-DNS, FluentBit, AWS LBC, etc.)
  # The flag ONLY applies to the 4 bootstrap addons that traditional EKS needs
  bootstrap_self_managed_addons = false

  vpc_config {
    subnet_ids              = var.eks_node_group_subnets
    endpoint_private_access = local.eks_private_enabled
    endpoint_public_access  = local.eks_public_enabled
    public_access_cidrs     = local.eks_public_cidrs
    security_group_ids      = [aws_security_group.cluster_security_group.id]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  compute_config {
    enabled       = true
    node_role_arn = aws_iam_role.eks_node_role.arn
    node_pools    = ["general-purpose", "system"]
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  enabled_cluster_log_types = var.eks_cluster_logging_types

  tags = var.tags
}

################################################################################
# CloudWatch Log Group (Cluster Logging)
################################################################################

resource "aws_cloudwatch_log_group" "unreal_cluster_cloudwatch" {
  #checkov:skip=CKV_AWS_158:Ensure that CloudWatch Log Group is encrypted by KMS
  region            = var.region
  name_prefix       = var.eks_cluster_cloudwatch_log_group_prefix
  retention_in_days = 365
}

################################################################################
# EKS Access Entries (Cluster Access)
################################################################################

# EKS Access Entries for additional users/services
resource "aws_eks_access_entry" "additional" {
  for_each = var.eks_access_entries

  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  principal_arn = each.value.principal_arn
  type          = each.value.type

  depends_on = [aws_eks_cluster.unreal_cloud_ddc_eks_cluster]
}

# EKS Access Entry for CodeBuild (cluster setup)
resource "aws_eks_access_entry" "codebuild_cluster_setup" {
  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  principal_arn = aws_iam_role.cluster_setup_codebuild_role.arn
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.unreal_cloud_ddc_eks_cluster]
}

resource "aws_eks_access_policy_association" "codebuild_cluster_setup" {
  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.cluster_setup_codebuild_role.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.codebuild_cluster_setup]
}

resource "aws_eks_access_policy_association" "additional" {
  for_each = {
    for combo in flatten([
      for entry_key, entry_value in var.eks_access_entries : [
        for policy_idx, policy in entry_value.policy_associations : {
          key           = "${entry_key}-${policy_idx}"
          principal_arn = entry_value.principal_arn
          policy_arn    = policy.policy_arn
          access_scope  = policy.access_scope
        }
      ]
    ]) : combo.key => combo
  }

  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  policy_arn    = each.value.policy_arn
  principal_arn = each.value.principal_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = each.value.access_scope.namespaces
  }

  depends_on = [aws_eks_access_entry.additional]
}

# NOTE: EKS Access Entry for node role already exists automatically
# EKS Auto Mode creates access entries for all node roles automatically
# Confirmed: AmazonEKSAutoNodePolicy is already attached

################################################################################
# CodeBuild Project (Cluster Setup)
################################################################################

# CodeBuild project for cluster setup (replaces null_resource operations)
resource "aws_codebuild_project" "cluster_setup" {
  name         = "${local.name_prefix}-cluster-setup"
  description  = "Configure EKS cluster with AWS Load Balancer Controller and custom NodePools"
  service_role = aws_iam_role.cluster_setup_codebuild_role.arn
  
  artifacts {
    type = "NO_ARTIFACTS"
  }
  
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"
    
    environment_variable {
      name  = "CLUSTER_NAME"
      value = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
    }
    
    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }
    
    environment_variable {
      name  = "VPC_ID"
      value = var.vpc_id
    }
    
    environment_variable {
      name  = "LBC_ROLE_ARN"
      value = var.is_primary_region ? aws_iam_role.aws_load_balancer_controller_role[0].arn : ""
    }
    
    environment_variable {
      name  = "NODE_ROLE_NAME"
      value = aws_iam_role.eks_node_role.name
    }
    
    environment_variable {
      name  = "NODE_SUBNETS"
      value = join(",", var.eks_node_group_subnets)
    }
    
    environment_variable {
      name  = "HELM_LBC_ARGS"
      value = "--set clusterName=${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${var.is_primary_region ? aws_iam_role.aws_load_balancer_controller_role[0].arn : ""} --set region=${var.region} --set vpcId=${var.vpc_id}"
    }
    
    environment_variable {
      name  = "HELM_CERT_ARGS"
      value = "--version v1.16.2 --namespace cert-manager --create-namespace --set crds.enabled=true --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${var.is_primary_region && var.enable_certificate_manager ? aws_iam_role.cert_manager_role[0].arn : ""}"
    }
    
    environment_variable {
      name  = "CLUSTER_SG_ID"
      value = aws_security_group.cluster_security_group.id
    }
    
    environment_variable {
      name  = "NAME_PREFIX"
      value = local.name_prefix
    }
    
    environment_variable {
      name  = "IS_PRIMARY_REGION"
      value = var.is_primary_region ? "true" : "false"
    }
    
    environment_variable {
      name  = "ENABLE_CERT_MANAGER"
      value = var.enable_certificate_manager ? "true" : "false"
    }
    
    environment_variable {
      name  = "CERT_MANAGER_ROLE_ARN"
      value = var.is_primary_region && var.enable_certificate_manager ? aws_iam_role.cert_manager_role[0].arn : ""
    }
  }
  
  # TEMPORARILY REMOVED: VPC configuration causing CodeBuild to fail completely
  # TODO: Fix networking - CodeBuild needs internet access for tools + EKS API access
  # vpc_config {
  #   vpc_id = var.vpc_id
  #   subnets = var.eks_node_group_subnets
  #   security_group_ids = [aws_security_group.cluster_security_group.id]
  # }
  
  source {
    type = "S3"
    location = "${aws_s3_bucket.manifests.bucket}/assets.zip"
    buildspec = file("${path.module}/buildspecs/cluster-setup.yml")
  }
  
  tags = var.tags
}

################################################################################
# Terraform Actions (Cluster Setup Orchestration)
################################################################################

# Terraform Action to start cluster setup
action "aws_codebuild_start_build" "cluster_setup" {
  config {
    project_name = aws_codebuild_project.cluster_setup.name
    timeout      = 1800  # 30 minutes
  }
}

# Trigger cluster setup after EKS cluster exists
resource "terraform_data" "cluster_setup_trigger" {
  input = {
    cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
    cluster_version = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
    region          = var.region
    # Force trigger when buildspec changes (for fixing cluster setup scripts)
    buildspec_hash  = filemd5("${path.module}/buildspecs/cluster-setup.yml")
    # Force trigger when S3 assets change (manifests, scripts)
    assets_hash     = data.archive_file.assets.output_md5
    # Final validation: EKS setup → Deploy → Test sequence working correctly
    validation_comment = "eks-deploy-test-sequence-validated"
  }
  
  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.aws_codebuild_start_build.cluster_setup]
    }
  }
  
  depends_on = [
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster,
    aws_iam_role.cluster_setup_codebuild_role,
    aws_iam_role.aws_load_balancer_controller_role,
    aws_iam_role.cert_manager_role,
    aws_s3_object.assets
  ]
}

# LEGACY: AWS Load Balancer Controller CRDs (replaced by CodeBuild)
# Install AWS Load Balancer Controller CRDs
# resource "null_resource" "aws_load_balancer_controller_crds" {
#   count = var.is_primary_region ? 1 : 0
# 
#   triggers = {
#     cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
#     region = var.region
#   }
# 
#   # NOTE: Cannot use null in string interpolation - Terraform requires empty string instead of null
#   # This is a Terraform limitation where ${condition ? "value" : null} fails in string templates
#   provisioner "local-exec" {
#     command = <<-EOT
#       set -e
#       echo "[CRD-INSTALL] Installing AWS Load Balancer Controller CRDs..."
# 
#       # Configure kubectl access
#       aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region}${var.debug ? " --debug" : ""}
# 
#       # Wait for cluster API readiness
#       kubectl cluster-info --request-timeout=30s${var.debug ? " -v=10" : ""}
# 
#       # Install CRDs
#       kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml --timeout=60s${var.debug ? " -v=10" : ""}
# 
#       # Wait for CRDs to be established
#       kubectl wait --for condition=established --timeout=60s crd/targetgroupbindings.elbv2.k8s.aws${var.debug ? " -v=10" : ""} || true
# 
#       echo "[CRD-SUCCESS] AWS Load Balancer Controller CRDs installed"
#     EOT
#   }
# 
#   provisioner "local-exec" {
#     when = destroy
#     command = <<-EOT
#       echo "[CRD-CLEANUP] Starting CRD cleanup..."
# 
#       # Configure kubectl (ignore failures if cluster deleted)
#       aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
#         echo "[CRD-CLEANUP] Cluster already deleted, skipping cleanup"
#         exit 0
#       }
# 
#       # Remove finalizers from any remaining TargetGroupBindings
#       kubectl get targetgroupbindings --all-namespaces -o name 2>/dev/null | while read tgb; do
#         kubectl patch "$tgb" --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
#       done
# 
#       # Delete CRDs
#       kubectl delete -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml --timeout=30s || true
# 
#       echo "[CRD-SUCCESS] Cleanup completed"
#     EOT
#   }
# 
#   depends_on = [
#     aws_eks_cluster.unreal_cloud_ddc_eks_cluster
#   ]
# }

# LEGACY: AWS Load Balancer Controller (replaced by CodeBuild)
# Install AWS Load Balancer Controller with IRSA
# resource "null_resource" "aws_load_balancer_controller" {
#   count = var.is_primary_region ? 1 : 0
# 
#   triggers = {
#     cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
#     region = var.region
#     role_arn = aws_iam_role.aws_load_balancer_controller_role[0].arn
#     # Force restart when IAM policies change
#     security_group_policy_arn = aws_iam_policy.aws_load_balancer_controller_security_groups[0].arn
#   }
# 
#   provisioner "local-exec" {
#     command = <<-EOT
#       set -e
#       echo "[HELM-INSTALL] Installing AWS Load Balancer Controller with IRSA..."
# 
#       # Configure kubectl access
#       ${var.debug ? "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region} --debug" : "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region}"}
# 
#       # Wait for cluster API readiness
#       ${var.debug ? "kubectl cluster-info --request-timeout=30s -v=10" : "kubectl cluster-info --request-timeout=30s"}
# 
#       # Add EKS Helm repository
#       helm repo add eks https://aws.github.io/eks-charts || true
#       helm repo update
# 
#       # Install AWS Load Balancer Controller with IRSA and system node tolerations
#       ${var.debug ? "helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller --debug" : "helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller"} \\
#         -n kube-system \\
#         --set clusterName=${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} \\
#         --set serviceAccount.create=true \\
#         --set serviceAccount.name=aws-load-balancer-controller \\
#         --set serviceAccount.annotations.eks\\\\.amazonaws\\\\.com/role-arn=${aws_iam_role.aws_load_balancer_controller_role[0].arn} \\
#         --set region=${var.region} \\
#         --set vpcId=${var.vpc_id} \\
#         --wait --timeout 3m
# 
#       # Force restart to pick up fresh IAM permissions (handles IAM eventual consistency)
#       echo "[HELM-RESTART] Restarting controller to ensure fresh IAM permissions..."
#       kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
#       kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s
# 
#       echo "[HELM-SUCCESS] AWS Load Balancer Controller installation completed"
#     EOT
#   }
# 
#   provisioner "local-exec" {
#     when = destroy
#     command = <<-EOT
#       echo "[HELM-CLEANUP] Starting cleanup..."
# 
#       # Configure kubectl (ignore failures if cluster deleted)
#       aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
#         echo "[HELM-CLEANUP] Cluster already deleted, skipping cleanup"
#         exit 0
#       }
# 
#       # Uninstall AWS Load Balancer Controller
#       helm uninstall aws-load-balancer-controller -n kube-system || true
# 
#       echo "[HELM-SUCCESS] Cleanup completed"
#     EOT
#   }
# 
#   depends_on = [
#     null_resource.aws_load_balancer_controller_crds,
#     aws_iam_openid_connect_provider.eks_oidc,
#     aws_iam_role.aws_load_balancer_controller_role,
#     aws_iam_role_policy_attachment.aws_load_balancer_controller_security_groups
#   ]
# }

# LEGACY: Cert Manager (replaced by CodeBuild)
# Install Cert Manager with IRSA (Infrastructure Component)
# resource "null_resource" "cert_manager" {
#   count = var.is_primary_region && var.enable_certificate_manager ? 1 : 0
# 
#   triggers = {
#     cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
#     region = var.region
#     role_arn = aws_iam_role.cert_manager_role[0].arn
#   }
# 
#   provisioner "local-exec" {
#     command = <<-EOT
#       set -e
#       echo "[CERT-INSTALL] Installing Cert Manager with IRSA..."
# 
#       # Configure kubectl access
#       ${var.debug ? "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region} --debug" : "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region}"}
# 
#       # Wait for cluster API readiness
#       ${var.debug ? "kubectl cluster-info --request-timeout=30s -v=10" : "kubectl cluster-info --request-timeout=30s"}
# 
#       # Add Jetstack Helm repository
#       helm repo add jetstack https://charts.jetstack.io || true
#       helm repo update
# 
#       # Install Cert Manager with IRSA
#       helm upgrade --install cert-manager jetstack/cert-manager \\
#         --version v1.16.2 \\
#         --namespace cert-manager \\
#         --create-namespace \\
#         --set crds.enabled=true \\
#         --set serviceAccount.annotations.eks\\\\.amazonaws\\\\.com/role-arn=${aws_iam_role.cert_manager_role[0].arn}${var.debug ? " \\\\\n#         --debug" : ""} \\
#         --wait --timeout 10m
# 
#       echo "[CERT-SUCCESS] Cert Manager installation completed"
#     EOT
#   }
# 
#   provisioner "local-exec" {
#     when = destroy
#     command = <<-EOT
#       echo "[CERT-CLEANUP] Starting cleanup..."
# 
#       # Configure kubectl (ignore failures if cluster deleted)
#       aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
#         echo "[CERT-CLEANUP] Cluster already deleted, skipping cleanup"
#         exit 0
#       }
# 
#       # Uninstall Cert Manager
#       helm uninstall cert-manager -n cert-manager || true
# 
#       echo "[CERT-SUCCESS] Cleanup completed"
#     EOT
#   }
# 
#   depends_on = [
#     null_resource.aws_load_balancer_controller,
#     aws_iam_role.cert_manager_role
#   ]
# }

# TargetGroupBinding removed - LoadBalancer service creates NLB directly via AWS Load Balancer Controller

################################################################################
# Custom NodePool (Workload-Specific)
################################################################################

# LEGACY: DDC NodePool (replaced by CodeBuild)
# DDC NodePool - always created for NVMe performance requirements
# resource "null_resource" "ddc_nodepool" {
# 
#   triggers = {
#     cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
#     region = var.region
#     node_role_arn = aws_iam_role.eks_node_role.arn
#     subnets = join(",", var.eks_node_group_subnets)
#     trust_policy = aws_iam_role.eks_node_role.assume_role_policy
#   }
# 
#   provisioner "local-exec" {
#     command = <<-EOT
#       set -e
#       echo "[NODEPOOL-CREATE] Creating DDC NodePool for i-family instances with NVMe storage..."
# 
#       # Configure kubectl access
#       if ! ${var.debug ? "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region} --debug" : "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region}"}; then
#         echo "[NODEPOOL-ERROR] Failed to configure kubectl access"
#         exit 1
#       fi
# 
#       # Wait for cluster to be ready
#       if ! ${var.debug ? "kubectl cluster-info --request-timeout=30s -v=10" : "kubectl cluster-info --request-timeout=30s"}; then
#         echo "[NODEPOOL-ERROR] Cluster not ready"
#         exit 1
#       fi
# 
#       # Wait for IAM policy propagation (AWS eventual consistency)
#       echo "[NODEPOOL-WAIT] Waiting for IAM policy propagation..."
#       sleep 30
# 
#       # Verify cluster role has custom tagging policy
#       echo "[NODEPOOL-VERIFY] Verifying cluster role IAM permissions..."
#       aws iam list-attached-role-policies --role-name ${aws_iam_role.eks_cluster_role.name} --region ${var.region} | grep -q "cluster-custom-tags" || {
#         echo "[NODEPOOL-WARNING] Cluster role missing custom tagging policy, waiting additional 30s..."
#         sleep 30
#       }
# 
#       # Delete existing NodeClass to force recreation with new IAM permissions
#       echo "[NODEPOOL-DELETE] Deleting existing NodeClass to force recreation..."
#       kubectl delete nodeclass ddc-nodeclass --ignore-not-found=true
# 
#       # Create NodeClass for DDC workloads (NVMe optimized)
#       echo "[NODEPOOL-CREATE] Creating NodeClass with IAM role: ${aws_iam_role.eks_node_role.name}"
#       if ! ${var.debug ? "kubectl apply -f - -v=10" : "kubectl apply -f -"} <<EOF
# apiVersion: eks.amazonaws.com/v1
# kind: NodeClass
# metadata:
#   name: ddc-nodeclass
# spec:
#   role: ${aws_iam_role.eks_node_role.name}
#   subnetSelectorTerms:
# ${join("\n", [for subnet in var.eks_node_group_subnets : "    - id: ${subnet}"])}
#   securityGroupSelectorTerms:
#     - id: ${aws_security_group.cluster_security_group.id}
#   # EBS ephemeral storage (fallback when NVMe not available)
#   ephemeralStorage:
#     iops: 3000
#     size: 80Gi
#     throughput: 125
#   # EKS Auto Mode automatically formats NVMe drives to /mnt/.ephemeral
#   # DDC pods use hostPath volume to access NVMe storage
#   networkPolicy: DefaultAllow
#   snatPolicy: Random
#   tags:
#     Name: "${local.name_prefix}-ddc-node"
#     Purpose: "DDC-NVMe-Storage"
#     NodePool: "ddc-compute"
#     StorageType: "NVMe-Primary-EBS-Fallback"
#     Cluster: "${local.name_prefix}-cluster-${var.region}"
# EOF
#       then
#         echo "[NODEPOOL-ERROR] Failed to create NodeClass - check IAM permissions for ec2:CreateLaunchTemplate"
#         exit 1
#       fi
# 
#       echo "[NODEPOOL-SUCCESS] NodeClass created successfully, creating NodePool..."
# 
#       # Create DDC NodePool (prioritizes i-family instances with NVMe)
#       if ! ${var.debug ? "kubectl apply -f - -v=10" : "kubectl apply -f -"} <<EOF
# apiVersion: karpenter.sh/v1
# kind: NodePool
# metadata:
#   name: ddc-compute
# spec:
#   template:
#     spec:
#       nodeClassRef:
#         group: eks.amazonaws.com
#         kind: NodeClass
#         name: ddc-nodeclass
#       requirements:
#         - key: karpenter.sh/capacity-type
#           operator: In
#           values: ["on-demand"]
#         # Target instances with sufficient NVMe storage for DDC caching
#         - key: eks.amazonaws.com/instance-local-nvme
#           operator: Gt
#           values: ["100"]  # At least 100GB NVMe storage for DDC performance
#         # Previous i-family restriction (can revert if needed)
#         # - key: eks.amazonaws.com/instance-category
#         #   operator: In
#         #   values: ["i"]  # i=storage optimized with NVMe
#         # - key: eks.amazonaws.com/instance-generation
#         #   operator: Gt
#         #   values: ["3"]  # Gen 4+ for better NVMe performance (i4i, i4g, etc.)
#         - key: kubernetes.io/arch
#           operator: In
#           values: ["amd64"]
#         - key: kubernetes.io/os
#           operator: In
#           values: ["linux"]
#       terminationGracePeriod: 24h0m0s
#   disruption:
#     consolidateAfter: 30s
#     consolidationPolicy: WhenEmptyOrUnderutilized
#     budgets:
#       - nodes: "10%"
# EOF
#       then
#         echo "[NODEPOOL-ERROR] Failed to create NodePool"
#         exit 1
#       fi
# 
#       echo "[NODEPOOL-SUCCESS] DDC NodePool created successfully"
# 
# 
#     EOT
#   }
# 
#   provisioner "local-exec" {
#     when = destroy
#     command = <<-EOT
#       echo "[NODEPOOL-CLEANUP] Removing custom NodePool..."
# 
#       # Configure kubectl (ignore failures if cluster deleted)
#       aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
#         echo "[NODEPOOL-CLEANUP] Cluster already deleted, skipping cleanup"
#         exit 0
#       }
# 
#       # Delete custom NodePool and NodeClass
#       kubectl delete nodepool ddc-compute || true
#       kubectl delete nodeclass ddc-nodeclass || true
# 
#       echo "[NODEPOOL-SUCCESS] Cleanup completed"
#     EOT
#   }
# 
#   depends_on = [
#     aws_eks_cluster.unreal_cloud_ddc_eks_cluster
#   ]
# }
