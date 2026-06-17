data "aws_region" "current" {}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${local.is_arm64 ? "arm64" : "x86_64"}"
}

locals {
  instance_family = split(".", var.instance_type)[0]
  is_arm64        = contains(["c8gd", "c8g", "c7gd", "c7g", "c7gn", "m7g", "m7gd", "m8g", "r7g", "r7gd", "r8g", "t4g", "im4gn", "is4gen", "x2gd", "hpc7g"], local.instance_family)
  ecr_registry    = split("/", var.container_image)[0]
  hmac_key        = var.hmac_key != null ? var.hmac_key : random_id.hmac[0].hex
}

# =============================================================================
# HMAC Key (generated when not provided)
# =============================================================================

resource "random_id" "hmac" {
  count       = var.hmac_key == null ? 1 : 0
  byte_length = 32 # 32 bytes = 64 hex characters
}

# =============================================================================
# TLS — Self-signed cert (CA:FALSE, IP SAN)
# =============================================================================

resource "tls_private_key" "edge" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "edge" {
  private_key_pem = tls_private_key.edge.private_key_pem

  subject {
    common_name = "${var.name_prefix}-edge-pod"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]

  # IP SAN added after instance creation via userdata (openssl regeneration)
  # This cert is a fallback — userdata generates the real cert with IP SAN
}

# =============================================================================
# Security Group
# =============================================================================

resource "aws_security_group" "edge" {
  name_prefix = "${var.name_prefix}-edge-"
  description = "Edge pod - QUIC/gRPC ingress, write tier egress"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-edge" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "client_quic_grpc_tcp" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.edge.id
  description       = "Client gRPC TCP (${each.value})"
  cidr_ipv4         = each.value
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "client_quic_grpc_udp" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.edge.id
  description       = "Client QUIC UDP (${each.value})"
  cidr_ipv4         = each.value
  from_port         = 41337
  to_port           = 41337
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "client_http" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.edge.id
  description       = "Client HTTP (${each.value})"
  cidr_ipv4         = each.value
  from_port         = 41339
  to_port           = 41339
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.edge.id
  description       = "All outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow edge pod to reach write tier's security group on replication + gRPC ports
resource "aws_vpc_security_group_ingress_rule" "write_tier_from_edge" {
  security_group_id            = var.server_security_group_id
  description                  = "Edge pod replication + gRPC"
  referenced_security_group_id = aws_security_group.edge.id
  from_port                    = 41337
  to_port                      = 41340
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "write_tier_from_edge_udp" {
  security_group_id            = var.server_security_group_id
  description                  = "Edge pod QUIC replication (UDP)"
  referenced_security_group_id = aws_security_group.edge.id
  from_port                    = 41340
  to_port                      = 41340
  ip_protocol                  = "udp"
}

# =============================================================================
# IAM Role + Instance Profile (ECR pull + SSM)
# =============================================================================

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "edge" {
  name_prefix        = "${var.name_prefix}-edge-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.edge.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "ecr" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ecr" {
  name   = "ecr-pull"
  role   = aws_iam_role.edge.id
  policy = data.aws_iam_policy_document.ecr.json
}

resource "aws_iam_instance_profile" "edge" {
  name_prefix = "${var.name_prefix}-edge-"
  role        = aws_iam_role.edge.name
  tags        = var.tags
}

# =============================================================================
# EC2 Instance
# =============================================================================

resource "aws_instance" "edge" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.edge.name
  vpc_security_group_ids = [aws_security_group.edge.id]

  user_data_base64 = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    ecr_region      = data.aws_region.current.name
    ecr_registry    = local.ecr_registry
    ca_cert_pem     = var.ca_certificate_pem
    container_image = var.container_image
    write_tier_dns  = var.write_tier_dns
    hmac_key        = local.hmac_key
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-edge-pod" })
}
