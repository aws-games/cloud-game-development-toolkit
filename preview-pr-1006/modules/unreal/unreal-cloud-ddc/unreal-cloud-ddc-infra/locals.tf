
locals {
  tags = merge(var.tags, {
    "environment" = var.environment
  })

  name_prefix = "${var.project_prefix}-${var.name}"
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
  scylla_user_data_primary_node = jsonencode(
    {
      "scylla_yaml" : {
        "cluster_name" : local.scylla_variables.scylla-cluster-name
      }
      #required to ensure that scylla does not pick up the wrong config on boot prior to SSM configuring the instance
      #if scylla boots with an ip that is incorrect you have to delete data and reset the node prior to reconfiguring.
      "start_scylla_on_first_boot" : true
    }
  )
  scylla_user_data_other_nodes = jsonencode(
    {
      "scylla_yaml" : {
        "cluster_name" : local.scylla_variables.scylla-cluster-name,
        "seed_provider" : [{
        "parameters" : [{ "seeds" : aws_instance.scylla_ec2_instance_seed[0].private_ip }] }]
      }
      #required to ensure that scylla does not pick up the wrong config on boot prior to SSM configuring the instance
      #if scylla boots with an ip that is incorrect you have to delete data and reset the node prior to reconfiguring.
      "start_scylla_on_first_boot" : true
    }
  )
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

  scylla_node_ips = concat(
    [for instance in aws_instance.scylla_ec2_instance_seed : instance.private_ip],
    [for instance in aws_instance.scylla_ec2_instance_other_nodes : instance.private_ip]
  )

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
%{for ip in local.scylla_node_ips~}
    - ${ip}
%{endfor~}
  labels:
    cluster: "unreal-cloud-ddc"
    dc: ${var.region}
EOF

# Set proper permissions
sudo chmod 644 prometheus/scylla_servers.yml

cd /home/ec2-user/scylla-monitoring-4.9.4
sudo ./start-all.sh -l -d /home/ec2-user/prometheus/data -a /home/ec2-user/prometheus/alertmanager

--//--\
MONITORING_EOF
}
