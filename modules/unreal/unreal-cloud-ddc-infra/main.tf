
locals {
  sg_rules_all = [
    { port : 7000, description : "ScyllaDB Inter-node communication (RPC)", protocol : "tcp" },
    { port : 7001, description : "ScyllaDB SSL inter-node communication (RPC)", protocol : "tcp" },
    { port : 7199, description : "ScyllaDB JMX management", protocol : "tcp" },
    { port : 9042, description : "ScyllaDB CQL (native_transport_port)", protocol : "tcp" },
    { port : 9100, description : "ScyllaDB node_exporter (Optionally)", protocol : "tcp" },
    { port : 9142, description : "ScyllaDB SSL CQL (secure client to node)", protocol : "tcp" },
    { port : 9160, description : "Scylla client port (Thrift)", protocol : "tcp" },
    { port : 9180, description : "ScyllaDB Prometheus API", protocol : "tcp" },
    { port : 10000, description : "ScyllaDB REST API", protocol : "tcp" },
    { port : 19042, description : "Native shard-aware transport port", protocol : "tcp" },
    { port : 19142, description : "Native shard-aware transport port (ssl)", protocol : "tcp" }
  ]
  scylla_variables = {
    scylla-cluster-name = var.name
  }
  scylla_user_data = jsonencode(
    { "scylla_yaml" : {
      "cluster_name" : local.scylla_variables.scylla-cluster-name,
      "seed_provider" : [
        { "class_name" : "org.apache.cassandra.locator.SimpleSeedProvider",
          "parameters" : [
            { "seeds" : "test-ip" }
          ]
        }
      ]
      },
  "start_scylla_on_first_boot" : true })
  nvme-pre-bootstrap-userdata = <<EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="//"

--//
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
sudo mkfs.ext4 -E nodiscard /dev/nvme1n1
sudo mkdir /data
sudo mount /dev/nvme1n1 /data
--//--\
EOF
}

data "aws_ami" "scylla_ami" {
  most_recent = true
  owners      = ["797456418907", "158855661827"]
  filter {
    name   = "name"
    values = [var.scylla_ami_name]
  }
  filter {
    name   = "architecture"
    values = [var.scylla_architecture]
  }
}

################################################################################
# Scylla DNS Name Record
################################################################################
resource "aws_route53_zone" "scylla_zone" {
  #checkov:skip=CKV2_AWS_38:Ensure Domain Name System Security Extensions (DNSSEC) signing is enabled for Amazon Route 53 public hosted zones
  #checkov:skip=CKV2_AWS_39:Ensure Domain Name System (DNS) query logging is enabled for Amazon Route 53 hosted zones
  name = var.scylla_dns

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "scylla_records" {
  name    = var.scylla_dns
  ttl     = 60
  type    = "A"
  zone_id = aws_route53_zone.scylla_zone.zone_id

  records = [for scylla in aws_instance.scylla_ec2_instance : scylla.private_ip]
}

################################################################################
# Scylla SG
################################################################################
resource "aws_security_group" "scylla_security_group" {
  name        = "${var.name}-scylla-sg"
  description = "Security group for ScyllaDB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "unreal-cloud-ddc-scylla-sg"
  }
}

################################################################################
# Scylla Security Group Rules
################################################################################
resource "aws_security_group_rule" "ssm_egress_sg_rules" {
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = 0
  description       = "Egress All"
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}


################################################################################
# Scylla Security Group to Peer CIDR Rules
################################################################################
resource "aws_security_group_rule" "peer_cidr_blocks_ingress_sg_rules" {
  for_each          = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = each.value.port
  description       = each.value.description
  protocol          = each.value.protocol
  cidr_blocks       = var.peer_cidr_blocks
  to_port           = each.value.port
  type              = "ingress"
}

resource "aws_security_group_rule" "peer_cidr_blocks_scylla_egress_sg_rules" {
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = 0
  protocol          = "tcp"
  cidr_blocks       = var.peer_cidr_blocks
  to_port           = 0
  type              = "egress"
  description       = "Peer block egress"
}
################################################################################
# Scylla Security Group to Self Rules
################################################################################
resource "aws_security_group_rule" "self_ingress_sg_rules" {
  for_each          = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = each.value.port
  description       = each.value.description
  protocol          = each.value.protocol
  self              = true
  to_port           = each.value.port
  type              = "ingress"
}

resource "aws_security_group_rule" "self_scylla_egress_sg_rules" {
  security_group_id = aws_security_group.scylla_security_group.id
  from_port         = 0
  protocol          = "tcp"
  self              = true
  to_port           = 0
  type              = "egress"
  description       = "Self SG Egress"
}

# ################################################################################
# # Scylla Security Group to NVME sg Rules
# ################################################################################
# resource "aws_security_group_rule" "nvme_node_group_to_scylla_ingress_sg_rules" {
#   for_each                 = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
#   security_group_id        = aws_security_group.scylla_security_group.id
#   from_port                = each.value.port
#   description              = each.value.description
#   protocol                 = each.value.protocol
#   source_security_group_id = aws_security_group.nvme_security_group.id
#   to_port                  = each.value.port
#   type                     = "ingress"
# }
#
# resource "aws_security_group_rule" "nvme_node_group_to_scylla_egress_sg_rules" {
#   security_group_id        = aws_security_group.scylla_security_group.id
#   from_port                = 0
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.nvme_security_group.id
#   to_port                  = 0
#   type                     = "egress"
#   description              = "NVME SG to Scylla SG Egress"
# }
#
# ################################################################################
# # Scylla Security Group to Worker sg Rules
# ################################################################################
# resource "aws_security_group_rule" "worker_node_group_to_scylla_ingress_sg_rules" {
#   for_each                 = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
#   security_group_id        = aws_security_group.scylla_security_group.id
#   from_port                = each.value.port
#   description              = each.value.description
#   protocol                 = each.value.protocol
#   source_security_group_id = aws_security_group.worker_security_group.id
#   to_port                  = each.value.port
#   type                     = "ingress"
# }
#
# resource "aws_security_group_rule" "worker_node_group_to_scylla_egress_sg_rules" {
#   security_group_id        = aws_security_group.scylla_security_group.id
#   from_port                = 0
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.worker_security_group.id
#   to_port                  = 0
#   type                     = "egress"
#   description              = "Worker SG to Scylla SG Egress"
# }

################################################################################
# Scylla Security Group to Monitoring sg Rules
################################################################################
# resource "aws_security_group_rule" "monitoring_node_group_to_scylla_ingress_sg_rules" {
#   for_each                 = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
#   security_group_id        = aws_security_group.scylla_security_group.id
#   from_port                = each.value.port
#   description              = each.value.description
#   protocol                 = each.value.protocol
#   source_security_group_id = aws_security_group.monitoring_security_group.id
#   to_port                  = each.value.port
#   type                     = "ingress"
# }
#
# resource "aws_security_group_rule" "monitoring_node_group_to_scylla_egress_sg_rules" {
#   security_group_id        = aws_security_group.scylla_security_group.id
#   from_port                = 0
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.monitoring_security_group.id
#   to_port                  = 0
#   type                     = "egress"
#   description              = "Monitoring SG to Scylla SG Egress"
# }

# ###############################################################################
# System SG Rules
# ################################################################################
# resource "aws_security_group_rule" "scylla_to_system_group_ingress_sg_rules" {
#   for_each                 = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
#   security_group_id        = aws_security_group.system_security_group.id
#   from_port                = each.value.port
#   description              = each.value.description
#   protocol                 = each.value.protocol
#   source_security_group_id = aws_security_group.scylla_security_group.id
#   to_port                  = each.value.port
#   type                     = "ingress"
# }
#
# resource "aws_security_group_rule" "scylla_to_monitoring_group_egress_sg_rules" {
#   security_group_id        = aws_security_group.monitoring_security_group.id
#   from_port                = 0
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.scylla_security_group.id
#   to_port                  = 0
#   type                     = "egress"
#   description              = "Scylla SG to Montoring SG Egress"
# }

################################################################################
# Worker SG Rules
################################################################################
resource "aws_security_group_rule" "scylla_to_worker_group_ingress_sg_rules" {
  for_each                 = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
  security_group_id        = aws_security_group.worker_security_group.id
  from_port                = each.value.port
  description              = each.value.description
  protocol                 = each.value.protocol
  source_security_group_id = aws_security_group.scylla_security_group.id
  to_port                  = each.value.port
  type                     = "ingress"
}
#
# resource "aws_security_group_rule" "scylla_to_worker_group_egress_sg_rules" {
#   security_group_id        = aws_security_group.worker_security_group.id
#   from_port                = 0
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.scylla_security_group.id
#   to_port                  = 0
#   type                     = "egress"
#   description              = "Scylla SG to Worker SG Egress"
# }
################################################################################
# NVME SG Rules
################################################################################
resource "aws_security_group_rule" "scylla_to_nvme_group_ingress_sg_rules" {
  for_each                 = { for sg_rule in local.sg_rules_all : sg_rule.port => sg_rule }
  security_group_id        = aws_security_group.nvme_security_group.id
  from_port                = each.value.port
  description              = each.value.description
  protocol                 = each.value.protocol
  source_security_group_id = aws_security_group.scylla_security_group.id
  to_port                  = each.value.port
  type                     = "ingress"
}
#
# resource "aws_security_group_rule" "scylla_to_nvme_group_egress_sg_rules" {
#   security_group_id        = aws_security_group.nvme_security_group.id
#   from_port                = 0
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.scylla_security_group.id
#   to_port                  = 0
#   type                     = "egress"
#   description              = "Scylla SG to NVME SG Egress"
# }
################################################################################
# Scylla Role
################################################################################
resource "aws_iam_role" "scylla_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "ScyllaDbRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  name_prefix         = "scylla-db-"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}
################################################################################
# Scylla Instance Profile
################################################################################

resource "aws_iam_instance_profile" "scylla_instance_profile" {
  name = "scylladb_instance_profile"
  role = aws_iam_role.scylla_role.name
}
################################################################################
# Scylla Instances
################################################################################
resource "aws_instance" "scylla_ec2_instance" {
  count = length(var.scylla_private_subnets)

  ami             = data.aws_ami.scylla_ami.id
  instance_type   = var.scylla_instance_type
  security_groups = [aws_security_group.scylla_security_group.id]
  monitoring      = true

  subnet_id = element(var.private_subnets, count.index)

  user_data                   = local.scylla_user_data
  user_data_replace_on_change = true
  ebs_optimized               = true

  iam_instance_profile = aws_iam_instance_profile.scylla_instance_profile.name

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    throughput  = var.scylla_db_throughput
    volume_size = var.scylla_db_storage
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  tags = {
    Name = "${var.name}-scylla-db"
  }
}
################################################################################
# EKS Node IAM Role
################################################################################

resource "aws_iam_role" "monitoring_node_group_role" {
  name_prefix = "unreal-cloud-ddc-eks-node-group-role-"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  inline_policy {
    name = "external-dns-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = ["route53:ChangeResourceRecordSets"]
          Effect = "Allow"
          Resource = [
            "arn:aws:route53:::hostedzone/*"
          ]
        },
        {
          Action = [
            "route53:ListHostedZones",
            "route53:ListResourceRecordSets",
            "route53:ListTagsForResource"
          ],
          Effect   = "Allow"
          Resource = ["*"]
        }
      ]
    })
  }
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_role" "nvme_node_group_role" {
  name_prefix = "unreal-cloud-ddc-eks-node-group-role-"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_role" "worker_node_group_role" {
  name_prefix = "unreal-cloud-ddc-eks-node-group-role-"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

################################################################################
# System Security Group
################################################################################
resource "aws_security_group" "system_security_group" {
  name        = "${var.name}-system-sg"
  description = "Security group for system node group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "unreal-cloud-ddc-system-sg"
  }
}

resource "aws_security_group_rule" "system_egress_sg_rules" {
  security_group_id = aws_security_group.system_security_group.id
  from_port         = 0
  description       = "Egress All"
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
################################################################################
# NVME Security Group
################################################################################
resource "aws_security_group" "nvme_security_group" {
  name        = "${var.name}-nvme-sg"
  description = "Security group for nvme node group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "unreal-cloud-ddc-nvme-sg"
  }
}

resource "aws_security_group_rule" "nvme_egress_sg_rules" {
  security_group_id = aws_security_group.nvme_security_group.id
  from_port         = 0
  description       = "Egress All"
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
################################################################################
# Worker Security Group
################################################################################
resource "aws_security_group" "worker_security_group" {
  name        = "${var.name}-worker-sg"
  description = "Security group for nvme node group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "unreal-cloud-ddc-worker-sg"
  }
}

resource "aws_security_group_rule" "worker_egress_sg_rules" {
  security_group_id = aws_security_group.worker_security_group.id
  from_port         = 0
  description       = "Egress All"
  protocol          = "-1"
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}



################################################################################
# EKS Cluster
################################################################################
resource "aws_iam_role" "eks_cluster_role" {
  name_prefix = "unreal-cloud-ddc-eks-cluster-role-"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]
}

resource "aws_eks_cluster" "unreal_cloud_ddc_eks_cluster" {
  #checkov:skip=CKV_AWS_39:Ensure Amazon EKS public endpoint disabled
  #checkov:skip=CKV_AWS_58:Ensure EKS Cluster has Secrets Encryption Enabled
  #checkov:skip=CKV_AWS_339:Ensure EKS clusters run on a supported Kubernetes version
  name                      = var.name
  role_arn                  = aws_iam_role.eks_cluster_role.arn
  version                   = "1.29"
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]



  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.eks_cluster_access_cidr
    security_group_ids = [
      aws_security_group.system_security_group.id,
      aws_security_group.worker_security_group.id,
      aws_security_group.nvme_security_group.id
    ]
  }
}

resource "aws_cloudwatch_log_group" "unreal_cluster_cloudwatch" {
  #checkov:skip=CKV_AWS_158:Ensure that CloudWatch Log Group is encrypted by KMS
  name_prefix       = "/aws/eks/${var.name}/cluster"
  retention_in_days = 365

}

data "aws_ssm_parameter" "eks_ami_latest_release" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version}/amazon-linux-2/recommended/release_version"
}

################################################################################
# Worker Node Group
################################################################################
resource "aws_eks_node_group" "worker_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "unreal-cloud-ddc-worker-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_latest_release.value)
  node_role_arn   = aws_iam_role.worker_node_group_role.arn
  subnet_ids      = var.private_subnets

  labels = {
    "unreal-cloud-ddc/node-type" = "worker"
  }

  taint {
    key    = "role"
    value  = "unreal-cloud-ddc"
    effect = "NO_SCHEDULE"
  }

  scaling_config {
    desired_size = var.worker_managed_node_desired_size
    max_size     = var.worker_managed_node_max_size
    min_size     = 0
  }
  launch_template {
    id      = aws_launch_template.worker_launch_template.id
    version = aws_launch_template.worker_launch_template.latest_version
  }
  tags = {
    Name = "unreal-cloud-ddc-worker-instance"
  }
}

resource "aws_launch_template" "worker_launch_template" {
  #checkov:skip=CKV_AWS_341:Ensure Launch template should not have a metadata response hop limit greater than 1
  name_prefix   = "unreal-ddc-worker-launch-template"
  instance_type = var.worker_managed_node_instance_type
  vpc_security_group_ids = [
    aws_security_group.worker_security_group.id,
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].cluster_security_group_id,
    aws_security_group.scylla_security_group.id
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "unreal-ddc-worker-instance"
    }
  }
}

################################################################################
# NVME Node Group
################################################################################
resource "aws_eks_node_group" "nvme_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "unreal-cloud-ddc-nvme-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_latest_release.value)
  node_role_arn   = aws_iam_role.nvme_node_group_role.arn
  subnet_ids      = var.private_subnets

  labels = {
    "unreal-cloud-ddc/node-type" = "nvme"
  }

  taint {
    key    = "role"
    value  = "unreal-cloud-ddc"
    effect = "NO_SCHEDULE"
  }

  scaling_config {
    desired_size = var.nvme_managed_node_desired_size
    max_size     = var.nvme_managed_node_max_size
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.nvme_launch_template.id
    version = aws_launch_template.nvme_launch_template.latest_version
  }

}

resource "aws_launch_template" "nvme_launch_template" {
  #checkov:skip=CKV_AWS_341:Ensure Launch template should not have a metadata response hop limit greater than 1
  name_prefix   = "unreal-ddc-nvme-launch-template"
  instance_type = var.nvme_managed_node_instance_type
  user_data     = base64encode(local.nvme-pre-bootstrap-userdata)
  vpc_security_group_ids = [
    aws_security_group.nvme_security_group.id,
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].cluster_security_group_id,
    aws_security_group.scylla_security_group.id
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "unreal-ddc-nvme-instance"
    }
  }
}

################################################################################
# System Node Group
################################################################################
resource "aws_eks_node_group" "system_node_group" {
  cluster_name    = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name
  node_group_name = "unreal-cloud-ddc-monitoring-ng"
  version         = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_latest_release.value)
  node_role_arn   = aws_iam_role.monitoring_node_group_role.arn
  subnet_ids      = var.private_subnets
  labels = {
    "pool" = "system-pool"
  }

  launch_template {
    id      = aws_launch_template.system_launch_template.id
    version = aws_launch_template.system_launch_template.latest_version
  }

  scaling_config {
    desired_size = var.system_managed_node_desired_size
    max_size     = var.system_managed_node_max_size
    min_size     = 1
  }
  tags = {
    Name = "unreal-cloud-ddc-system-instance"
  }
}

resource "aws_launch_template" "system_launch_template" {
  #checkov:skip=CKV_AWS_341:Ensure Launch template should not have a metadata response hop limit greater than 1
  name_prefix   = "unreal-ddc-system-launch-template"
  instance_type = var.system_managed_node_instance_type

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  vpc_security_group_ids = [
    aws_security_group.system_security_group.id,
    aws_eks_cluster.unreal_cloud_ddc_eks_cluster.vpc_config[0].cluster_security_group_id
  ]

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "unreal-ddc-system-instance"
    }
  }
}
################################################################################
# EKS Cluster Open ID Connect Provider
################################################################################
data "tls_certificate" "eks_tls_certificate" {
  url = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "unreal_cloud_ddc_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_tls_certificate.certificates[0].sha1_fingerprint]
  url             = data.tls_certificate.eks_tls_certificate.url
}

resource "aws_eks_identity_provider_config" "eks_cluster_oidc_association" {
  cluster_name = aws_eks_cluster.unreal_cloud_ddc_eks_cluster.name

  oidc {
    client_id                     = substr(aws_eks_cluster.unreal_cloud_ddc_eks_cluster.identity[0].oidc[0].issuer, -32, -1)
    identity_provider_config_name = "unreal-ddc-oidc-provider"
    issuer_url                    = "https://${aws_iam_openid_connect_provider.unreal_cloud_ddc_oidc_provider.url}"
  }
}

################################################################################
# S3
################################################################################

resource "aws_s3_bucket" "unreal_ddc_s3_bucket" {
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:Ensure S3 buckets should have event notifications enabled
  #checkov:skip=CKV_AWS_144:Ensure that S3 bucket has cross-region replication enabled
  bucket_prefix = "${var.name}-s3-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "unreal-s3-bucket" {
  #checkov:skip=CKV2_AWS_67:Ensure AWS S3 bucket encrypted with Customer Managed Key (CMK) has regular rotation
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = "aws/s3"
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "unreal_ddc_s3_acls" {
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


################################################################################
# Log Bucket
################################################################################


resource "aws_s3_bucket" "unreal_ddc_logging_s3_bucket" {
  #checkov:skip=CKV_AWS_21:Ensure all data stored in the S3 bucket have versioning enabled
  #checkov:skip=CKV2_AWS_61:Ensure that an S3 bucket has a lifecycle configuration
  #checkov:skip=CKV2_AWS_62:Ensure S3 buckets should have event notifications enabled
  #checkov:skip=CKV_AWS_144:Ensure that S3 bucket has cross-region replication enabled
  bucket_prefix = "${var.name}-logging-s3-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "unreal-s3-logging-bucket" {
  #checkov:skip=CKV2_AWS_67:Ensure AWS S3 bucket encrypted with Customer Managed Key (CMK) has regular rotation
  bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = "aws/s3"
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "unreal_ddc_log_s3_acls" {
  bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_logging" "unreal-s3-log" {
  bucket = aws_s3_bucket.unreal_ddc_s3_bucket.id

  target_bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id
  target_prefix = "log/unreal-ddc-bucket/"
}

resource "aws_s3_bucket_logging" "unreal-log-s3-log" {
  bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id

  target_bucket = aws_s3_bucket.unreal_ddc_logging_s3_bucket.id
  target_prefix = "log/unreal-ddc-loggin-bucket/"
}


################################################################################
# SSM
################################################################################

resource "aws_ssm_document" "config_scylla" {
  name            = "${var.name}-scylla-run-command"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    "schemaVersion" : "2.2",
    "description" : "Config Scylla",
    "mainSteps" : [
      {
        "action" : "aws:runShellScript",
        "name" : "ConfigScylla",
        "inputs" : {
          "runCommand" : [
            "sudo apt-get update && sudo apt-get -y upgrade",
            "sudo sed -i 's/- seeds: test-ip.*$/- seeds: ${aws_instance.scylla_ec2_instance[0].private_ip} /g' /etc/scylla/scylla.yaml",
            "echo \"Config of /etc/scylla/scylla.yaml Done\"",
            "sudo reboot now"
          ]
        }
      }
    ]
    }
  )
}

resource "aws_ssm_association" "scylla_config_association" {
  name = aws_ssm_document.config_scylla.name

  targets {
    key    = "tag:Name"
    values = ["${var.name}-scylla-db"]
  }
}
