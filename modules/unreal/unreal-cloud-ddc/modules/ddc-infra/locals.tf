
locals {
  tags = merge(var.tags, {
    "environment" = var.environment
  })

  name_prefix = "${var.project_prefix}-${var.name}"
  
  # EKS Access Configuration Logic
  eks_public_enabled = contains(["public", "hybrid"], var.eks_access_config.mode)
  eks_private_enabled = contains(["private", "hybrid"], var.eks_access_config.mode)
  
  # Public access CIDRs (only when public access enabled)
  eks_public_cidrs = local.eks_public_enabled && var.eks_access_config.public != null ? (
    var.eks_access_config.public.prefix_list_id != null ? [] : var.eks_access_config.public.allowed_cidrs
  ) : []
  
  # Private access configuration
  eks_private_config = var.eks_access_config.private
  
  # Logging configuration from parent module
  log_base_prefix = var.log_base_prefix
  scylla_logging_enabled = var.scylla_logging_enabled
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
      # Required to ensure that scylla does not pick up the wrong config on boot prior to SSM configuring the instance
      # If scylla boots with an ip that is incorrect you have to delete data and reset the node prior to reconfiguring
      "start_scylla_on_first_boot" : true,
      # CloudWatch agent configuration for log shipping
      "post_configuration_script" : local.scylla_logging_enabled ? [
        "yum update -y",
        "yum install -y amazon-cloudwatch-agent",
        "cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'",
        "{",
        "  \"logs\": {",
        "    \"logs_collected\": {",
        "      \"files\": {",
        "        \"collect_list\": [",
        "          {",
        "            \"file_path\": \"/var/log/scylla/scylla.log\",",
        "            \"log_group_name\": \"${local.log_base_prefix}/service/scylla\",",
        "            \"log_stream_name\": \"{instance_id}-scylla\",",
        "            \"timezone\": \"UTC\"",
        "          }",
        "        ]",
        "      }",
        "    }",
        "  },",
        "  \"agent\": {",
        "    \"region\": \"${var.region}\"",
        "  }",
        "}",
        "EOF",
        "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s",
        "systemctl enable amazon-cloudwatch-agent"
      ] : []
    }
  )
  scylla_user_data_other_nodes = jsonencode(
    {
      "scylla_yaml" : {
        "cluster_name" : local.scylla_variables.scylla-cluster-name,
        "seed_provider" : [{
        "parameters" : [{ "seeds" : var.create_seed_node && length(aws_instance.scylla_ec2_instance_seed) > 0 ? aws_instance.scylla_ec2_instance_seed[0].private_ip : var.existing_scylla_seed }] }]
      }
      # Required to ensure that scylla does not pick up the wrong config on boot prior to SSM configuring the instance
      # If scylla boots with an ip that is incorrect you have to delete data and reset the node prior to reconfiguring
      "start_scylla_on_first_boot" : true,
      # CloudWatch agent configuration for log shipping
      "post_configuration_script" : local.scylla_logging_enabled ? [
        "yum update -y",
        "yum install -y amazon-cloudwatch-agent",
        "cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'",
        "{",
        "  \"logs\": {",
        "    \"logs_collected\": {",
        "      \"files\": {",
        "        \"collect_list\": [",
        "          {",
        "            \"file_path\": \"/var/log/scylla/scylla.log\",",
        "            \"log_group_name\": \"${local.log_base_prefix}/service/scylla\",",
        "            \"log_stream_name\": \"{instance_id}-scylla\",",
        "            \"timezone\": \"UTC\"",
        "          }",
        "        ]",
        "      }",
        "    }",
        "  },",
        "  \"agent\": {",
        "    \"region\": \"${var.region}\"",
        "  }",
        "}",
        "EOF",
        "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s",
        "systemctl enable amazon-cloudwatch-agent"
      ] : []
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

  scylla_node_ips = var.scylla_config != null ? concat(
    [for instance in aws_instance.scylla_ec2_instance_seed : instance.private_ip],
    [for instance in aws_instance.scylla_ec2_instance_other_nodes : instance.private_ip],
    var.existing_scylla_ips
  ) : []

  # Database type detection
  database_type = var.scylla_config != null ? "scylla" : "keyspaces"
  
  # ScyllaDB datacenter naming - use replace() for proper region naming
  scylla_datacenter_name = replace(var.region, "-1", "")
  scylla_keyspace_suffix = replace(var.region, "-", "_")
  
  # Keyspace naming - use parent module's keyspace name if provided
  keyspace_name = var.keyspace_name != null ? var.keyspace_name : "jupiter_local_ddc_${replace(var.region, "-", "_")}"
  
  # Database connection abstraction for ddc-services
  database_connection = var.scylla_config != null ? {
    type = "scylla"
    host = "scylla.${var.region}.compute.internal"  # Will be updated with actual private DNS
    port = 9042
    auth_type = "credentials"
    keyspace_name = local.keyspace_name
    multi_region = false
  } : {
    type = "keyspaces"
    host = "cassandra.${var.region}.amazonaws.com"
    port = 9142
    auth_type = "iam"
    keyspace_name = local.keyspace_name
    multi_region = var.amazon_keyspaces_config != null ? length([for k, v in var.amazon_keyspaces_config.keyspaces : k if v.enable_cross_region_replication]) > 0 : false
  }

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
%{if length(var.scylla_ips_by_region) > 0~}
%{for region, ips in var.scylla_ips_by_region~}
- targets:
%{for ip in ips~}
    - ${ip}
%{endfor~}
  labels:
    cluster: "unreal-cloud-ddc"
    dc: ${replace(region, "-1", "")}
    region: ${region}
%{endfor~}
%{else~}
# Fallback for single region or legacy configuration
- targets:
%{for ip in local.scylla_node_ips~}
    - ${ip}
%{endfor~}
  labels:
    cluster: "unreal-cloud-ddc"
    dc: ${local.scylla_datacenter_name}
    region: ${var.region}
%{endif~}
EOF

# Set proper permissions
sudo chmod 644 prometheus/scylla_servers.yml

cd /home/ec2-user/scylla-monitoring-4.9.4
sudo ./start-all.sh -l -d /home/ec2-user/prometheus/data -a /home/ec2-user/prometheus/alertmanager

--//--\
MONITORING_EOF

}
