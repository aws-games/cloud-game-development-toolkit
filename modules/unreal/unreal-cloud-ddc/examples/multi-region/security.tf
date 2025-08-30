##########################################
# Security Groups for My IP Access (Both Regions)
##########################################
resource "aws_security_group" "allow_my_ip_primary" {
  provider    = aws.primary
  name        = "${local.project_prefix}-allow-my-ip-primary"
  description = "Allow inbound traffic from my IP to DDC and monitoring services in primary region"
  vpc_id      = aws_vpc.primary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-allow-my-ip-primary"
  })
}

resource "aws_security_group" "allow_my_ip_secondary" {
  provider    = aws.secondary
  name        = "${local.project_prefix}-allow-my-ip-secondary"
  description = "Allow inbound traffic from my IP to DDC and monitoring services in secondary region"
  vpc_id      = aws_vpc.secondary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-allow-my-ip-secondary"
  })
}

##########################################
# Get My Public IP
##########################################
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

##########################################
# Primary Region Security Group Rules
##########################################
# Allow HTTPS access to primary monitoring dashboard
resource "aws_vpc_security_group_ingress_rule" "allow_https_primary" {
  security_group_id = aws_security_group.allow_my_ip_primary.id
  description       = "Allow HTTPS traffic from my public IP to primary monitoring dashboard"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow HTTP access to primary monitoring dashboard
resource "aws_vpc_security_group_ingress_rule" "allow_http_primary" {
  security_group_id = aws_security_group.allow_my_ip_primary.id
  description       = "Allow HTTP traffic from my public IP to primary monitoring dashboard"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow ICMP for troubleshooting primary
resource "aws_vpc_security_group_ingress_rule" "allow_icmp_primary" {
  security_group_id = aws_security_group.allow_my_ip_primary.id
  description       = "Allow ICMP traffic from my public IP for troubleshooting primary region"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

##########################################
# Secondary Region Security Group Rules
##########################################
# Allow HTTPS access to secondary monitoring dashboard
resource "aws_vpc_security_group_ingress_rule" "allow_https_secondary" {
  security_group_id = aws_security_group.allow_my_ip_secondary.id
  description       = "Allow HTTPS traffic from my public IP to secondary monitoring dashboard"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow HTTP access to secondary monitoring dashboard
resource "aws_vpc_security_group_ingress_rule" "allow_http_secondary" {
  security_group_id = aws_security_group.allow_my_ip_secondary.id
  description       = "Allow HTTP traffic from my public IP to secondary monitoring dashboard"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# Allow ICMP for troubleshooting secondary
resource "aws_vpc_security_group_ingress_rule" "allow_icmp_secondary" {
  security_group_id = aws_security_group.allow_my_ip_secondary.id
  description       = "Allow ICMP traffic from my public IP for troubleshooting secondary region"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

##########################################
# Cross-Region ScyllaDB Security Groups
##########################################
resource "aws_security_group" "scylla_cross_region_primary" {
  provider    = aws.primary
  name        = "${local.project_prefix}-scylla-cross-region-primary"
  description = "Allow ScyllaDB cross-region communication from secondary region"
  vpc_id      = aws_vpc.primary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-scylla-cross-region-primary"
  })
}

resource "aws_security_group" "scylla_cross_region_secondary" {
  provider    = aws.secondary
  name        = "${local.project_prefix}-scylla-cross-region-secondary"
  description = "Allow ScyllaDB cross-region communication from primary region"
  vpc_id      = aws_vpc.secondary.id

  tags = merge(local.tags, {
    Name = "${local.project_prefix}-scylla-cross-region-secondary"
  })
}

# Allow ScyllaDB gossip protocol from secondary to primary
resource "aws_vpc_security_group_ingress_rule" "scylla_gossip_primary" {
  security_group_id = aws_security_group.scylla_cross_region_primary.id
  description       = "Allow ScyllaDB gossip protocol from secondary region"
  from_port         = 7000
  to_port           = 7001
  ip_protocol       = "tcp"
  cidr_ipv4         = aws_vpc.secondary.cidr_block
}

# Allow ScyllaDB CQL from secondary to primary
resource "aws_vpc_security_group_ingress_rule" "scylla_cql_primary" {
  security_group_id = aws_security_group.scylla_cross_region_primary.id
  description       = "Allow ScyllaDB CQL from secondary region"
  from_port         = 9042
  to_port           = 9042
  ip_protocol       = "tcp"
  cidr_ipv4         = aws_vpc.secondary.cidr_block
}

# Allow ScyllaDB gossip protocol from primary to secondary
resource "aws_vpc_security_group_ingress_rule" "scylla_gossip_secondary" {
  security_group_id = aws_security_group.scylla_cross_region_secondary.id
  description       = "Allow ScyllaDB gossip protocol from primary region"
  from_port         = 7000
  to_port           = 7001
  ip_protocol       = "tcp"
  cidr_ipv4         = aws_vpc.primary.cidr_block
}

# Allow ScyllaDB CQL from primary to secondary
resource "aws_vpc_security_group_ingress_rule" "scylla_cql_secondary" {
  security_group_id = aws_security_group.scylla_cross_region_secondary.id
  description       = "Allow ScyllaDB CQL from primary region"
  from_port         = 9042
  to_port           = 9042
  ip_protocol       = "tcp"
  cidr_ipv4         = aws_vpc.primary.cidr_block
}