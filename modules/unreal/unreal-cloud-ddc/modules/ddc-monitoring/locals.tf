locals {
  tags = merge(var.tags, {
    "environment" = var.environment
  })

  name_prefix = "${var.project_prefix}-${var.name}"

  scylla_monitoring_user_data = <<MONITORING_EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="//"

--//
Content-Type: text/x-shellscript; charset="us-ascii"

#!/usr/bin/env bash
# This script downloads the dependencies and then installs the scylla monitoring stack

# Update system and install dependencies
sudo yum update -y
sudo yum install -y docker

sudo mkdir -p /home/ec2-user/prometheus/data
sudo mkdir -p /home/ec2-user/prometheus/alertmanager
sudo chown -R ec2-user:ec2-user /home/ec2-user/prometheus

cat << 'EOF' > /home/ec2-user/prometheus/alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'

receivers:
- name: 'default'
EOF

cd /home/ec2-user

# Install and start Docker
sudo systemctl start docker
sudo groupadd docker
sudo usermod -aG docker $USER
sudo systemctl enable docker

# Install the Scylla Monitoring stack
wget https://github.com/scylladb/scylla-monitoring/archive/4.9.4.tar.gz
tar -xvf 4.9.4.tar.gz
cd scylla-monitoring-4.9.4

sudo systemctl restart docker

# Create the scylla_servers.yml file with server information
cat << EOF | sudo tee prometheus/scylla_servers.yml
# List of Scylla nodes to monitor
- targets:
%{for ip in var.scylla_node_ips~}
    - ${ip}
%{endfor~}
  labels:
    cluster: "unreal-cloud-ddc"
    dc: ${var.region}
    region: ${var.region}
EOF

# Set proper permissions
sudo chmod 644 prometheus/scylla_servers.yml

cd /home/ec2-user/scylla-monitoring-4.9.4
sudo ./start-all.sh -l -d /home/ec2-user/prometheus/data -a /home/ec2-user/prometheus/alertmanager

--//--\
MONITORING_EOF
}