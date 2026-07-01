# --- VPC ---

resource "aws_vpc" "secondary_agents" {
  count      = var.enable_secondary_region ? 1 : 0
  provider   = aws.secondary
  cidr_block = "10.2.0.0/16"
  tags       = merge(local.tags, { Name = "horde-agents-eu" })
}

resource "aws_internet_gateway" "secondary_agents" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_agents[0].id
  tags     = merge(local.tags, { Name = "horde-agents-eu" })
}

resource "aws_subnet" "secondary_agents_public" {
  count                   = var.enable_secondary_region ? 2 : 0
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary_agents[0].id
  cidr_block              = cidrsubnet("10.2.0.0/16", 8, count.index)
  availability_zone       = data.aws_availability_zones.secondary[0].names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "horde-agents-eu-public-${count.index}" })
}

resource "aws_subnet" "secondary_agents_private" {
  count             = var.enable_secondary_region ? 2 : 0
  provider          = aws.secondary
  vpc_id            = aws_vpc.secondary_agents[0].id
  cidr_block        = cidrsubnet("10.2.0.0/16", 8, count.index + 10)
  availability_zone = data.aws_availability_zones.secondary[0].names[count.index]
  tags              = merge(local.tags, { Name = "horde-agents-eu-private-${count.index}" })
}

resource "aws_route_table" "secondary_agents_public" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_agents[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary_agents[0].id
  }
  tags = merge(local.tags, { Name = "horde-agents-eu-public" })
}

resource "aws_route_table_association" "secondary_agents_public" {
  count          = var.enable_secondary_region ? 2 : 0
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_agents_public[count.index].id
  route_table_id = aws_route_table.secondary_agents_public[0].id
}

resource "aws_eip" "secondary_agents_nat" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.secondary
  domain   = "vpc"
  tags     = merge(local.tags, { Name = "horde-agents-eu-nat" })
}

resource "aws_nat_gateway" "secondary_agents" {
  count         = var.enable_secondary_region ? 1 : 0
  provider      = aws.secondary
  allocation_id = aws_eip.secondary_agents_nat[0].id
  subnet_id     = aws_subnet.secondary_agents_public[0].id
  tags          = merge(local.tags, { Name = "horde-agents-eu" })
}

resource "aws_route_table" "secondary_agents_private" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_agents[0].id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.secondary_agents[0].id
  }
  tags = merge(local.tags, { Name = "horde-agents-eu-private" })
}

resource "aws_route_table_association" "secondary_agents_private" {
  count          = var.enable_secondary_region ? 2 : 0
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_agents_private[count.index].id
  route_table_id = aws_route_table.secondary_agents_private[0].id
}

# --- AZs data source ---

data "aws_availability_zones" "secondary" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.secondary
  state    = "available"
}

# --- Security Group ---

resource "aws_security_group" "secondary_agents" {
  count       = var.enable_secondary_region ? 1 : 0
  provider    = aws.secondary
  name_prefix = "horde-agents-eu-"
  vpc_id      = aws_vpc.secondary_agents[0].id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS + gRPC to Horde server"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for apt package updates and dotnet install"
  }

  tags = merge(local.tags, { Name = "horde-agents-eu" })
}

# --- IAM ---

resource "aws_iam_role" "secondary_agents" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.secondary
  name     = "horde-agents-eu"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "secondary_agents_ssm" {
  count      = var.enable_secondary_region ? 1 : 0
  provider   = aws.secondary
  role       = aws_iam_role.secondary_agents[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "secondary_agents" {
  count    = var.enable_secondary_region ? 1 : 0
  provider = aws.secondary
  name     = "horde-agents-eu"
  role     = aws_iam_role.secondary_agents[0].name
}

# --- Launch Template ---

resource "aws_launch_template" "secondary_agents" {
  count         = var.enable_secondary_region ? 1 : 0
  provider      = aws.secondary
  name_prefix   = "horde-agent-eu-"
  image_id      = data.aws_ami.ubuntu_secondary.id
  instance_type = "c6a.large"

  iam_instance_profile {
    arn = aws_iam_instance_profile.secondary_agents[0].arn
  }

  vpc_security_group_ids = [aws_security_group.secondary_agents[0].id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs { volume_size = 64 }
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
set -euo pipefail

# Install .NET 10 runtime
apt-get update -y
apt-get install -y wget apt-transport-https
wget https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
chmod +x /tmp/dotnet-install.sh
/tmp/dotnet-install.sh --channel 10.0 --runtime dotnet --install-dir /opt/dotnet
ln -sf /opt/dotnet/dotnet /usr/local/bin/dotnet

# Download and install HordeAgent
mkdir -p /opt/horde-agent
cd /opt/horde-agent
wget -q "https://horde.gabeaws.people.aws.dev/api/v1/tools/horde-agent?action=download" -O horde-agent.zip
apt-get install -y unzip
unzip -o horde-agent.zip
rm horde-agent.zip

# Configure agent
cat > /opt/horde-agent/appsettings.json <<'SETTINGS'
{
  "Horde": {
    "ServerUrl": "https://horde.gabeaws.people.aws.dev"
  }
}
SETTINGS

# Create systemd service
cat > /etc/systemd/system/horde-agent.service <<'SERVICE'
[Unit]
Description=Horde Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/horde-agent
ExecStart=/usr/local/bin/dotnet /opt/horde-agent/HordeAgent.dll
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now horde-agent
EOF
  )

  tags = local.tags
}

# --- ASG ---

resource "aws_autoscaling_group" "secondary_agents" {
  count               = var.enable_secondary_region ? 1 : 0
  provider            = aws.secondary
  name_prefix         = "horde-agents-eu-"
  min_size            = 0
  max_size            = 2
  desired_capacity    = 0
  vpc_zone_identifier = aws_subnet.secondary_agents_private[*].id

  launch_template {
    id      = aws_launch_template.secondary_agents[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "horde-agent-eu"
    propagate_at_launch = true
  }
}
