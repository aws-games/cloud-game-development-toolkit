################################################################################
# EKS Cluster Security Group (Terraform-managed)
################################################################################

# Create our own EKS cluster security group with controlled rules
# EKS Auto Mode will use this security group for nodes via NodeClass securityGroupSelectorTerms (see bottom of this file)
resource "aws_security_group" "cluster_security_group" {
  region      = var.region
  name_prefix = "${local.name_prefix}-cluster-sg-"
  description = "Security group for EKS cluster nodes (Terraform-managed)"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-cluster-sg"
    # NOTE: Do NOT add "aws:eks:cluster-name" tag here!
    # AWS EKS automatically manages this tag and will strip it if manually added,
    # causing infinite Terraform drift. Let EKS manage its own system tags.
  })

  lifecycle {
    ignore_changes = [
      # AWS EKS automatically manages these tags - ignore to prevent drift
      tags["aws:eks:cluster-name"],
      tags_all["aws:eks:cluster-name"]
    ]
  }
}

# Allow all traffic within the security group (node-to-node communication)
resource "aws_vpc_security_group_ingress_rule" "cluster_self" {
  security_group_id            = aws_security_group.cluster_security_group.id
  description                  = "Allow all traffic from cluster nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.cluster_security_group.id

  tags = {
    Name = "${local.name_prefix}-cluster-self"
  }
}

# Allow EKS control plane to communicate with kubelet (CRITICAL for node registration)
resource "aws_vpc_security_group_ingress_rule" "cluster_kubelet" {
  security_group_id = aws_security_group.cluster_security_group.id
  description       = "EKS control plane to kubelet API"
  ip_protocol       = "tcp"
  from_port         = 10250
  to_port           = 10250
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-cluster-kubelet"
  }
}

# Allow HTTPS communication for EKS API
resource "aws_vpc_security_group_ingress_rule" "cluster_https" {
  security_group_id = aws_security_group.cluster_security_group.id
  description       = "HTTPS for EKS API communication"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-cluster-https"
  }
}

# Allow DNS resolution
resource "aws_vpc_security_group_ingress_rule" "cluster_dns" {
  security_group_id = aws_security_group.cluster_security_group.id
  description       = "DNS resolution"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-cluster-dns"
  }
}

# NLB to cluster security group rule moved to parent module to avoid circular dependency

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "cluster_egress" {
  security_group_id = aws_security_group.cluster_security_group.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${local.name_prefix}-cluster-egress"
  }
}

################################################################################
# EKS Auto Mode Cluster
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
# AWS Load Balancer Controller Installation
################################################################################

# Install AWS Load Balancer Controller CRDs
resource "null_resource" "aws_load_balancer_controller_crds" {
  count = var.is_primary_region ? 1 : 0

  triggers = {
    cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
    region = var.region
  }

  # NOTE: Cannot use null in string interpolation - Terraform requires empty string instead of null
  # This is a Terraform limitation where ${condition ? "value" : null} fails in string templates
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "[CRD-INSTALL] Installing AWS Load Balancer Controller CRDs..."

      # Configure kubectl access
      aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region}${var.debug ? " --debug" : ""}

      # Wait for cluster API readiness
      kubectl cluster-info --request-timeout=30s${var.debug ? " -v=10" : ""}

      # Install CRDs
      kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml --timeout=60s${var.debug ? " -v=10" : ""}

      # Wait for CRDs to be established
      kubectl wait --for condition=established --timeout=60s crd/targetgroupbindings.elbv2.k8s.aws${var.debug ? " -v=10" : ""} || true

      echo "[CRD-SUCCESS] AWS Load Balancer Controller CRDs installed"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "[CRD-CLEANUP] Starting CRD cleanup..."

      # Configure kubectl (ignore failures if cluster deleted)
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
        echo "[CRD-CLEANUP] Cluster already deleted, skipping cleanup"
        exit 0
      }

      # Remove finalizers from any remaining TargetGroupBindings
      kubectl get targetgroupbindings --all-namespaces -o name 2>/dev/null | while read tgb; do
        kubectl patch "$tgb" --type='merge' -p='{"metadata":{"finalizers":[]}}' || true
      done

      # Delete CRDs
      kubectl delete -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml --timeout=30s || true

      echo "[CRD-SUCCESS] Cleanup completed"
    EOT
  }

  depends_on = [
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster
  ]
}

# Install AWS Load Balancer Controller with IRSA
resource "null_resource" "aws_load_balancer_controller" {
  count = var.is_primary_region ? 1 : 0

  triggers = {
    cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
    region = var.region
    role_arn = aws_iam_role.aws_load_balancer_controller_role[0].arn
    # Force restart when IAM policies change
    security_group_policy_arn = aws_iam_policy.aws_load_balancer_controller_security_groups[0].arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "[HELM-INSTALL] Installing AWS Load Balancer Controller with IRSA..."

      # Configure kubectl access
      ${var.debug ? "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region} --debug" : "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region}"}

      # Wait for cluster API readiness
      ${var.debug ? "kubectl cluster-info --request-timeout=30s -v=10" : "kubectl cluster-info --request-timeout=30s"}

      # Add EKS Helm repository
      helm repo add eks https://aws.github.io/eks-charts || true
      helm repo update

      # Install AWS Load Balancer Controller with IRSA and system node tolerations
      ${var.debug ? "helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller --debug" : "helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller"} \
        -n kube-system \
        --set clusterName=${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${aws_iam_role.aws_load_balancer_controller_role[0].arn} \
        --set region=${var.region} \
        --set vpcId=${var.vpc_id} \
        --wait --timeout 3m

      # Force restart to pick up fresh IAM permissions (handles IAM eventual consistency)
      echo "[HELM-RESTART] Restarting controller to ensure fresh IAM permissions..."
      kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
      kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s

      echo "[HELM-SUCCESS] AWS Load Balancer Controller installation completed"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "[HELM-CLEANUP] Starting cleanup..."

      # Configure kubectl (ignore failures if cluster deleted)
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
        echo "[HELM-CLEANUP] Cluster already deleted, skipping cleanup"
        exit 0
      }

      # Uninstall AWS Load Balancer Controller
      helm uninstall aws-load-balancer-controller -n kube-system || true

      echo "[HELM-SUCCESS] Cleanup completed"
    EOT
  }

  depends_on = [
    null_resource.aws_load_balancer_controller_crds,
    aws_iam_openid_connect_provider.eks_oidc,
    aws_iam_role.aws_load_balancer_controller_role,
    aws_iam_role_policy_attachment.aws_load_balancer_controller_security_groups
  ]
}

# Install Cert Manager with IRSA (Infrastructure Component)
resource "null_resource" "cert_manager" {
  count = var.is_primary_region && var.enable_certificate_manager ? 1 : 0

  triggers = {
    cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
    region = var.region
    role_arn = aws_iam_role.cert_manager_role[0].arn
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "[CERT-INSTALL] Installing Cert Manager with IRSA..."

      # Configure kubectl access
      ${var.debug ? "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region} --debug" : "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region}"}

      # Wait for cluster API readiness
      ${var.debug ? "kubectl cluster-info --request-timeout=30s -v=10" : "kubectl cluster-info --request-timeout=30s"}

      # Add Jetstack Helm repository
      helm repo add jetstack https://charts.jetstack.io || true
      helm repo update

      # Install Cert Manager with IRSA
      helm upgrade --install cert-manager jetstack/cert-manager \
        --version v1.16.2 \
        --namespace cert-manager \
        --create-namespace \
        --set crds.enabled=true \
        --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${aws_iam_role.cert_manager_role[0].arn}${var.debug ? " \\\n        --debug" : ""} \
        --wait --timeout 10m

      echo "[CERT-SUCCESS] Cert Manager installation completed"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "[CERT-CLEANUP] Starting cleanup..."

      # Configure kubectl (ignore failures if cluster deleted)
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
        echo "[CERT-CLEANUP] Cluster already deleted, skipping cleanup"
        exit 0
      }

      # Uninstall Cert Manager
      helm uninstall cert-manager -n cert-manager || true

      echo "[CERT-SUCCESS] Cleanup completed"
    EOT
  }

  depends_on = [
    null_resource.aws_load_balancer_controller,
    aws_iam_role.cert_manager_role
  ]
}

# TargetGroupBinding removed - LoadBalancer service creates NLB directly via AWS Load Balancer Controller

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "unreal_cluster_cloudwatch" {
  #checkov:skip=CKV_AWS_158:Ensure that CloudWatch Log Group is encrypted by KMS
  region            = var.region
  name_prefix       = var.eks_cluster_cloudwatch_log_group_prefix
  retention_in_days = 365
}

# Node groups eliminated - EKS Auto Mode handles all node management automatically
# Custom NodePools below provide DDC-specific instance requirements
################################################################################
# EKS IAM Roles
################################################################################

# EKS cluster role still needed for cluster creation
resource "aws_iam_role" "eks_cluster_role" {
  name_prefix = "${local.name_prefix}-cluster-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-eks-cluster-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_compute_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_block_storage_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_load_balancing_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_networking_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

# Custom tagging policy for EKS Auto Mode - required for NodeClass with custom tags
data "aws_iam_policy_document" "eks_cluster_custom_tags" {
  statement {
    sid    = "Compute"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:RunInstances",
      "ec2:CreateLaunchTemplate"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = ["$${aws:PrincipalTag/eks:eks-cluster-name}"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/eks:kubernetes-node-class-name"
      values   = ["*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/eks:kubernetes-node-pool-name"
      values   = ["*"]
    }
  }
}

resource "aws_iam_policy" "eks_cluster_custom_tags" {
  name_prefix = "${local.name_prefix}-cluster-custom-tags-"
  policy      = data.aws_iam_policy_document.eks_cluster_custom_tags.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_custom_tags" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = aws_iam_policy.eks_cluster_custom_tags.arn
}





resource "aws_iam_role" "eks_node_role" {
  name_prefix = "${local.name_prefix}-node-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = [
          "ec2.amazonaws.com",
          "eks.amazonaws.com"
        ]
      }
    }]
  })

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-eks-node-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "eks_node_worker_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}







################################################################################
# EKS Access Entries - CRITICAL for cluster access
################################################################################

# EKS Access Entries for additional users/services
resource "aws_eks_access_entry" "additional" {
  for_each = var.eks_access_entries

  cluster_name  = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  principal_arn = each.value.principal_arn
  type          = each.value.type

  depends_on = [aws_eks_cluster.unreal_cloud_ddc_eks_cluster]
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
# Custom NodeClass and NodePool for i4i instances
################################################################################

# DDC NodePool - always created for NVMe performance requirements
resource "null_resource" "ddc_nodepool" {

  triggers = {
    cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
    region = var.region
    node_role_arn = aws_iam_role.eks_node_role.arn
    subnets = join(",", var.eks_node_group_subnets)
    trust_policy = aws_iam_role.eks_node_role.assume_role_policy
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "[NODEPOOL-CREATE] Creating DDC NodePool for i-family instances with NVMe storage..."

      # Configure kubectl access
      if ! ${var.debug ? "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region} --debug" : "aws eks update-kubeconfig --name ${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name} --region ${var.region}"}; then
        echo "[NODEPOOL-ERROR] Failed to configure kubectl access"
        exit 1
      fi

      # Wait for cluster to be ready
      if ! ${var.debug ? "kubectl cluster-info --request-timeout=30s -v=10" : "kubectl cluster-info --request-timeout=30s"}; then
        echo "[NODEPOOL-ERROR] Cluster not ready"
        exit 1
      fi

      # Wait for IAM policy propagation (AWS eventual consistency)
      echo "[NODEPOOL-WAIT] Waiting for IAM policy propagation..."
      sleep 30

      # Verify cluster role has custom tagging policy
      echo "[NODEPOOL-VERIFY] Verifying cluster role IAM permissions..."
      aws iam list-attached-role-policies --role-name ${aws_iam_role.eks_cluster_role.name} --region ${var.region} | grep -q "cluster-custom-tags" || {
        echo "[NODEPOOL-WARNING] Cluster role missing custom tagging policy, waiting additional 30s..."
        sleep 30
      }

      # Delete existing NodeClass to force recreation with new IAM permissions
      echo "[NODEPOOL-DELETE] Deleting existing NodeClass to force recreation..."
      kubectl delete nodeclass ddc-nodeclass --ignore-not-found=true

      # Create NodeClass for DDC workloads (NVMe optimized)
      echo "[NODEPOOL-CREATE] Creating NodeClass with IAM role: ${aws_iam_role.eks_node_role.name}"
      if ! ${var.debug ? "kubectl apply -f - -v=10" : "kubectl apply -f -"} <<EOF
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: ddc-nodeclass
spec:
  role: ${aws_iam_role.eks_node_role.name}
  subnetSelectorTerms:
${join("\n", [for subnet in var.eks_node_group_subnets : "    - id: ${subnet}"])}
  securityGroupSelectorTerms:
    - id: ${aws_security_group.cluster_security_group.id}
  # EBS ephemeral storage (fallback when NVMe not available)
  ephemeralStorage:
    iops: 3000
    size: 80Gi
    throughput: 125
  # EKS Auto Mode automatically formats NVMe drives to /mnt/.ephemeral
  # DDC pods use hostPath volume to access NVMe storage
  networkPolicy: DefaultAllow
  snatPolicy: Random
  tags:
    Name: "${local.name_prefix}-ddc-node"
    Purpose: "DDC-NVMe-Storage"
    NodePool: "ddc-compute"
    StorageType: "NVMe-Primary-EBS-Fallback"
    Cluster: "${local.name_prefix}-cluster-${var.region}"
EOF
      then
        echo "[NODEPOOL-ERROR] Failed to create NodeClass - check IAM permissions for ec2:CreateLaunchTemplate"
        exit 1
      fi

      echo "[NODEPOOL-SUCCESS] NodeClass created successfully, creating NodePool..."

      # Create DDC NodePool (prioritizes i-family instances with NVMe)
      if ! ${var.debug ? "kubectl apply -f - -v=10" : "kubectl apply -f -"} <<EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ddc-compute
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: ddc-nodeclass
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        # Target instances with sufficient NVMe storage for DDC caching
        - key: eks.amazonaws.com/instance-local-nvme
          operator: Gt
          values: ["100"]  # At least 100GB NVMe storage for DDC performance
        # Previous i-family restriction (can revert if needed)
        # - key: eks.amazonaws.com/instance-category
        #   operator: In
        #   values: ["i"]  # i=storage optimized with NVMe
        # - key: eks.amazonaws.com/instance-generation
        #   operator: Gt
        #   values: ["3"]  # Gen 4+ for better NVMe performance (i4i, i4g, etc.)
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
      terminationGracePeriod: 24h0m0s
  disruption:
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
    budgets:
      - nodes: "10%"
EOF
      then
        echo "[NODEPOOL-ERROR] Failed to create NodePool"
        exit 1
      fi

      echo "[NODEPOOL-SUCCESS] DDC NodePool created successfully"


    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "[NODEPOOL-CLEANUP] Removing custom NodePool..."

      # Configure kubectl (ignore failures if cluster deleted)
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} || {
        echo "[NODEPOOL-CLEANUP] Cluster already deleted, skipping cleanup"
        exit 0
      }

      # Delete custom NodePool and NodeClass
      kubectl delete nodepool ddc-compute || true
      kubectl delete nodeclass ddc-nodeclass || true

      echo "[NODEPOOL-SUCCESS] Cleanup completed"
    EOT
  }

  depends_on = [
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster
  ]
}
