################################################################################
# EKS Cluster Security Group (Terraform-managed)
################################################################################

# Create our own EKS cluster security group with controlled rules
# EKS Auto Mode will use this security group for nodes via NodeClass securityGroupSelectorTerms
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
  cidr_ipv4         = data.aws_vpc.main.cidr_block

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
  cidr_ipv4         = data.aws_vpc.main.cidr_block

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
  cidr_ipv4         = data.aws_vpc.main.cidr_block

  tags = {
    Name = "${local.name_prefix}-cluster-dns"
  }
}

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

# Allow CodeBuild access to DDC services (HTTP/HTTPS)
resource "aws_vpc_security_group_ingress_rule" "cluster_codebuild_http" {
  security_group_id = aws_security_group.cluster_security_group.id
  description       = "CodeBuild access to DDC HTTP services"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"  # CodeBuild uses AWS-managed public IPs

  tags = {
    Name = "${local.name_prefix}-cluster-codebuild-http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "cluster_codebuild_https" {
  security_group_id = aws_security_group.cluster_security_group.id
  description       = "CodeBuild access to DDC HTTPS services"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"  # CodeBuild uses AWS-managed public IPs

  tags = {
    Name = "${local.name_prefix}-cluster-codebuild-https"
  }
}

################################################################################
# ScyllaDB Security Group (Secondary Infrastructure)
################################################################################
resource "aws_security_group" "scylla_security_group" {
  region      = var.region
  name        = "${local.name_prefix}-scylla-sg"
  description = "Security group for ScyllaDB"
  vpc_id      = var.vpc_id

  # CRITICAL: Prevents cyclic dependency during destroy
  # This SG has self-referencing rules (referenced_security_group_id = this SG)
  # Creates circular dependency: SG rules depend on SG, but rules reference same SG
  # Without this, Terraform can't determine destroy order and hangs
  revoke_rules_on_delete = true

  tags = merge(var.tags,
    {
      Name = "${local.name_prefix}-scylla-sg"
    }
  )
}

################################################################################
# ScyllaDB Security Group Rules (Grouped Together)
################################################################################

# SSM Egress Rules for ScyllaDB
resource "aws_vpc_security_group_egress_rule" "ssm_egress_sg_rules" {
  region            = var.region
  security_group_id = aws_security_group.scylla_security_group.id
  description       = "Egress All"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ScyllaDB Security Group to Self Rules
resource "aws_vpc_security_group_ingress_rule" "self_ingress_sg_rules" {
  for_each                     = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
  region                       = var.region
  security_group_id            = aws_security_group.scylla_security_group.id
  from_port                    = each.value.port
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  referenced_security_group_id = aws_security_group.scylla_security_group.id
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "self_scylla_egress_sg_rules" {
  region                       = var.region
  security_group_id            = aws_security_group.scylla_security_group.id
  from_port                    = 0
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.scylla_security_group.id
  to_port                      = 0
  description                  = "Self SG Egress"
}

# ScyllaDB EKS Cluster Access Rules
# Allow VPC CIDR access to ScyllaDB CQL port for EKS Auto Mode
# EKS Auto Mode manages security groups automatically with timing dependencies
# VPC CIDR is the recommended pattern per AWS documentation for this scenario
resource "aws_vpc_security_group_ingress_rule" "scylla_from_vpc_cql" {
  region            = var.region
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = 9042
  to_port           = 9042
  description       = "ScyllaDB CQL port access from VPC CIDR (EKS Auto Mode standard pattern)"
  ip_protocol       = "tcp"
  cidr_ipv4         = data.aws_vpc.main.cidr_block
}



################################################################################
# Cross-Service Rules (EKS ↔ Additional Security Groups)
################################################################################

# ingress rule allowing ports 80 to 8091 from additional EKS security groups
# Note: cluster_security_group is now defined in this file (sg.tf)
resource "aws_vpc_security_group_ingress_rule" "cluster_additional_eks_sg_ingress_rule" {
  count                        = length(var.additional_eks_security_groups)
  region                       = var.region
  security_group_id            = aws_security_group.cluster_security_group.id
  description                  = "Allow traffic from additional EKS security groups to DDC services (ports 80-8091)"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 8091
  referenced_security_group_id = var.additional_eks_security_groups[count.index]
}




