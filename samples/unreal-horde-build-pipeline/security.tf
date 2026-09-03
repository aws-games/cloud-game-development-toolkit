##################################################
# Cross-Module Security Group Rules — JT-08
#
# SECURITY INVARIANT (user hard requirement — NO AWS security tickets):
#   Every INGRESS rule in this sample MUST be scoped to one of:
#     * a single-IP /32 CIDR (local.my_ip_cidr), or
#     * a referenced security group (referenced_security_group_id), or
#     * a private VPC CIDR (local.vpc_cidr_block or an agent subnet CIDR).
#   There is NEVER a 0.0.0.0/0 (or ::/0) INGRESS rule anywhere in this sample.
#
# The Horde and Perforce modules create their own security groups; this file
# only adds the cross-module rules that wire them together, plus the FSxN
# security group (which the AWS-native FSxN resources do not create on their
# own — see the file system's security_group_ids in netapp.tf).
#
# NOTE ON EGRESS: the Horde module already attaches an all-protocol egress rule
# (ip_protocol = "-1" to 0.0.0.0/0) to the agent security group. The explicit,
# narrowly-scoped egress rules below are ADDITIVE and exist to document the
# exact runtime flows the agents depend on (Secrets Manager + S3 endpoints,
# NFS to FSxN, and P4 to Perforce). Egress wildcards are acceptable; the
# invariant above applies to INGRESS only.
##################################################

##################################################
# FSx for ONTAP — Security Group
#
# The AWS-native FSxN resources in netapp.tf do not create a security group, so
# we create one here and attach it to the file system (see netapp.tf,
# security_group_ids). NFSv3 (used by the agents) requires the ONTAP data LIF
# to accept NFS (2049 tcp+udp) and the rpcbind/portmapper (111 tcp+udp).
##################################################

resource "aws_security_group" "fsxn" {
  name        = "${local.name_prefix}-fsxn"
  description = "FSx for ONTAP file system SG. NFSv3 from Horde agents only."
  vpc_id      = aws_vpc.horde_pipeline_vpc.id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-fsxn"
  })
}

# NFS (2049) TCP from the Horde agent SG — referenced SG (SG-to-SG).
resource "aws_vpc_security_group_ingress_rule" "fsxn_nfs_tcp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow NFS (2049/tcp) from Horde agents."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

# NFS (2049) UDP from the Horde agent SG — referenced SG (SG-to-SG).
resource "aws_vpc_security_group_ingress_rule" "fsxn_nfs_udp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow NFS (2049/udp) from Horde agents."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "udp"
}

# rpcbind / portmapper (111) TCP — required by ONTAP for NFSv3 mounts.
resource "aws_vpc_security_group_ingress_rule" "fsxn_rpcbind_tcp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow rpcbind (111/tcp) from Horde agents for NFSv3."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 111
  to_port                      = 111
  ip_protocol                  = "tcp"
}

# rpcbind / portmapper (111) UDP — required by ONTAP for NFSv3 mounts.
resource "aws_vpc_security_group_ingress_rule" "fsxn_rpcbind_udp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow rpcbind (111/udp) from Horde agents for NFSv3."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 111
  to_port                      = 111
  ip_protocol                  = "udp"
}

# ONTAP NFSv3 auxiliary RPC services on FIXED ports. NetApp ONTAP does NOT use
# dynamic mountd/NLM/status ports — it serves them on well-known fixed ports:
#   * mountd    (RPC 100005) -> 635  tcp+udp
#   * nlockmgr  (RPC 100021) -> 4045 tcp+udp  (NFSv3 file locking)
#   * status    (RPC 100024) -> 4046 tcp+udp  (NSM, lock recovery)
# The NFSv3 mount handshake queries portmapper (111) and then connects to
# mountd (635); without 635 the mount times out on the portmap query even
# though 111/2049 are open. Locking (4045/4046) is required for correct NFSv3
# operation once mounted. All scoped to the agent SG (referenced SG, never a
# wildcard) to preserve the ingress invariant.
resource "aws_vpc_security_group_ingress_rule" "fsxn_mountd_tcp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow ONTAP mountd (635/tcp) from Horde agents for NFSv3."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 635
  to_port                      = 635
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "fsxn_mountd_udp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow ONTAP mountd (635/udp) from Horde agents for NFSv3."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 635
  to_port                      = 635
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "fsxn_nlockmgr_tcp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow ONTAP nlockmgr (4045/tcp) from Horde agents for NFSv3 locking."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 4045
  to_port                      = 4045
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "fsxn_nlockmgr_udp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow ONTAP nlockmgr (4045/udp) from Horde agents for NFSv3 locking."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 4045
  to_port                      = 4045
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "fsxn_status_tcp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow ONTAP status/NSM (4046/tcp) from Horde agents for NFSv3 lock recovery."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 4046
  to_port                      = 4046
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "fsxn_status_udp_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow ONTAP status/NSM (4046/udp) from Horde agents for NFSv3 lock recovery."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 4046
  to_port                      = 4046
  ip_protocol                  = "udp"
}

# ONTAP management (443) from the Horde agent SG — the BuildGraph tasks call the
# ONTAP REST API (FlexClone / snapshot) against the management LIF over HTTPS.
resource "aws_vpc_security_group_ingress_rule" "fsxn_ontap_mgmt_from_agents" {
  security_group_id            = aws_security_group.fsxn.id
  description                  = "Allow ONTAP REST API (443/tcp) from Horde agents."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# FSxN egress — all protocols (egress wildcards are permitted by the invariant).
resource "aws_vpc_security_group_egress_rule" "fsxn_egress" {
  security_group_id = aws_security_group.fsxn.id
  description       = "Allow all egress from FSxN."
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

##################################################
# Horde EXTERNAL ALB — browser access LOCKED to the deployer's /32
#
# The Horde module does NOT create any ingress on the external ALB SG (by
# design), so this sample owns the browser-facing ingress. Both the HTTPS
# listener (443) and the HTTP->HTTPS redirect listener (80) are opened ONLY
# from local.my_ip_cidr. NEVER 0.0.0.0/0.
##################################################

resource "aws_vpc_security_group_ingress_rule" "horde_external_alb_https_from_my_ip" {
  security_group_id = module.horde.external_alb_sg_id
  description       = "Allow HTTPS (443) to Horde external ALB from the deployer /32 only."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = local.my_ip_cidr
}

resource "aws_vpc_security_group_ingress_rule" "horde_external_alb_http_from_my_ip" {
  security_group_id = module.horde.external_alb_sg_id
  description       = "Allow HTTP (80) redirect to Horde external ALB from the deployer /32 only."
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = local.my_ip_cidr
}

resource "aws_vpc_security_group_ingress_rule" "horde_external_alb_https_from_additional_cidrs" {
  for_each          = toset(var.additional_allowed_cidrs)
  security_group_id = module.horde.external_alb_sg_id
  description       = "Allow HTTPS (443) to Horde external ALB from an additional operator CIDR."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "horde_external_alb_http_from_additional_cidrs" {
  for_each          = toset(var.additional_allowed_cidrs)
  security_group_id = module.horde.external_alb_sg_id
  description       = "Allow HTTP (80) redirect to Horde external ALB from an additional operator CIDR."
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

##################################################
# Horde INTERNAL ALB — additional in-VPC access
#
# The Horde module already permits 443 from the agent SG and the service SG to
# the internal ALB (see modules/unreal/horde/sg.tf). We add a private-VPC-CIDR
# rule so any in-VPC operator/bastion host (e.g. the Perforce instance) can
# reach the internal Horde endpoint without a wildcard. Scoped to the VPC CIDR.
##################################################

resource "aws_vpc_security_group_ingress_rule" "horde_internal_alb_https_from_vpc" {
  security_group_id = module.horde.internal_alb_sg_id
  description       = "Allow HTTPS (443) to Horde internal ALB from within the VPC (private CIDR)."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = local.vpc_cidr_block
}

##################################################
# Perforce Server — P4 (1666) ingress
#
# The P4 Server lives in a private application subnet. It accepts P4 traffic
# ONLY from:
#   * the Horde agent SG (referenced SG) — both agent pools share one SG, so a
#     single referenced-SG rule covers sync and build agents; and
#   * the deployer's /32 (local.my_ip_cidr) for end-user P4 client access.
# NEVER 0.0.0.0/0.
##################################################

resource "aws_vpc_security_group_ingress_rule" "perforce_p4_from_agents" {
  count                        = local.deploy_perforce ? 1 : 0
  security_group_id            = module.perforce[0].p4_server_security_group_id
  description                  = "Allow P4 (1666/tcp) from Horde agents."
  referenced_security_group_id = module.horde.agent_security_group_id
  from_port                    = 1666
  to_port                      = 1666
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "perforce_p4_from_horde_service" {
  count                        = local.deploy_perforce ? 1 : 0
  security_group_id            = module.perforce[0].p4_server_security_group_id
  description                  = "Allow P4 (1666/tcp) from the Horde server (ECS service)."
  referenced_security_group_id = module.horde.service_security_group_id
  from_port                    = 1666
  to_port                      = 1666
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "perforce_p4_from_my_ip" {
  count             = local.deploy_perforce ? 1 : 0
  security_group_id = module.perforce[0].p4_server_security_group_id
  description       = "Allow P4 (1666/tcp) from the deployer /32 only for end-user P4 client access."
  from_port         = 1666
  to_port           = 1666
  ip_protocol       = "tcp"
  cidr_ipv4         = local.my_ip_cidr
}

##################################################
# Horde Agent — explicit egress (additive; documents required runtime flows)
##################################################

# 443 to the interface VPC endpoints SG (Secrets Manager). The S3 gateway
# endpoint is reached via route table (no SG), so no SG egress rule is needed
# for S3; this rule covers the Secrets Manager interface endpoint.
resource "aws_vpc_security_group_egress_rule" "agents_egress_https_to_endpoints" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow HTTPS (443) from agents to the interface VPC endpoints (Secrets Manager)."
  referenced_security_group_id = aws_security_group.vpc_endpoints.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# 2049 to the FSxN SG (NFS data).
resource "aws_vpc_security_group_egress_rule" "agents_egress_nfs_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow NFS (2049/tcp) from agents to FSxN."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

# 111 (rpcbind/portmapper) TCP to the FSxN SG — required for NFSv3 mounts.
resource "aws_vpc_security_group_egress_rule" "agents_egress_rpcbind_tcp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow rpcbind/portmapper (111/tcp) from agents to FSxN for NFSv3."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 111
  to_port                      = 111
  ip_protocol                  = "tcp"
}

# 111 (rpcbind/portmapper) UDP to the FSxN SG — required for NFSv3 mounts.
resource "aws_vpc_security_group_egress_rule" "agents_egress_rpcbind_udp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow rpcbind/portmapper (111/udp) from agents to FSxN for NFSv3."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 111
  to_port                      = 111
  ip_protocol                  = "udp"
}

# 2049 UDP to the FSxN SG (NFS data — NFSv3 uses UDP as well as TCP).
resource "aws_vpc_security_group_egress_rule" "agents_egress_nfs_udp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow NFS (2049/udp) from agents to FSxN."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "udp"
}

# ONTAP NFSv3 auxiliary RPC services on FIXED ports (mountd 635, nlockmgr 4045,
# status 4046 — tcp+udp each). These mirror the FSxN ingress rules above and
# are required for the mount handshake (mountd) and NFSv3 file locking. Without
# egress to mountd/635 the mount.nfs portmap query to mountd times out even
# though 111/2049 are reachable.
resource "aws_vpc_security_group_egress_rule" "agents_egress_mountd_tcp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow ONTAP mountd (635/tcp) from agents to FSxN for NFSv3."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 635
  to_port                      = 635
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "agents_egress_mountd_udp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow ONTAP mountd (635/udp) from agents to FSxN for NFSv3."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 635
  to_port                      = 635
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_egress_rule" "agents_egress_nlockmgr_tcp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow ONTAP nlockmgr (4045/tcp) from agents to FSxN for NFSv3 locking."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 4045
  to_port                      = 4045
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "agents_egress_nlockmgr_udp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow ONTAP nlockmgr (4045/udp) from agents to FSxN for NFSv3 locking."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 4045
  to_port                      = 4045
  ip_protocol                  = "udp"
}

resource "aws_vpc_security_group_egress_rule" "agents_egress_status_tcp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow ONTAP status/NSM (4046/tcp) from agents to FSxN for NFSv3 lock recovery."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 4046
  to_port                      = 4046
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "agents_egress_status_udp_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow ONTAP status/NSM (4046/udp) from agents to FSxN for NFSv3 lock recovery."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 4046
  to_port                      = 4046
  ip_protocol                  = "udp"
}

# 443 to the FSxN SG (ONTAP REST API for FlexClone / snapshot).
resource "aws_vpc_security_group_egress_rule" "agents_egress_ontap_mgmt_to_fsxn" {
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow ONTAP REST API (443/tcp) from agents to FSxN."
  referenced_security_group_id = aws_security_group.fsxn.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# 1666 to the Perforce server SG (P4 protocol).
resource "aws_vpc_security_group_egress_rule" "agents_egress_p4_to_perforce" {
  count                        = local.deploy_perforce ? 1 : 0
  security_group_id            = module.horde.agent_security_group_id
  description                  = "Allow P4 (1666/tcp) from agents to the Perforce server."
  referenced_security_group_id = module.perforce[0].p4_server_security_group_id
  from_port                    = 1666
  to_port                      = 1666
  ip_protocol                  = "tcp"
}
