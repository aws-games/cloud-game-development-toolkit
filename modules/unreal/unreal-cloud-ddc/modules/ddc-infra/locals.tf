
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
          "class_name" : "org.apache.cassandra.locator.SimpleSeedProvider",
          "parameters" : [{ "seeds" : var.create_seed_node ? "${aws_instance.scylla_ec2_instance_seed[0].private_ip}" : var.existing_scylla_seed }]
        }]
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



  scylla_monitoring_user_data = <<MONITORING_EOF
#!/bin/bash
# Install monitoring stack with runtime ScyllaDB discovery
sudo yum update -y
sudo yum install -y docker awscli
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Create directories
sudo mkdir -p /home/ec2-user/prometheus/data
sudo mkdir -p /home/ec2-user/prometheus/alertmanager
sudo chown -R ec2-user:ec2-user /home/ec2-user/prometheus

# Create alertmanager config
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

# Download and setup monitoring
cd /home/ec2-user
wget https://github.com/scylladb/scylla-monitoring/archive/4.9.4.tar.gz
tar -xvf 4.9.4.tar.gz
chown -R ec2-user:ec2-user scylla-monitoring-4.9.4

# Create runtime discovery script
cat << 'DISCOVERY_EOF' > /home/ec2-user/configure-scylla-monitoring.sh
#!/bin/bash
echo "Discovering ScyllaDB nodes..."

# Wait for ScyllaDB instances to be ready
for i in {1..30}; do
  SCYLLA_IPS=$(aws ec2 describe-instances \
    --region ${var.region} \
    --filters "Name=tag:Name,Values=*scylla*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].PrivateIpAddress' \
    --output text)
  
  if [ ! -z "$SCYLLA_IPS" ]; then
    echo "Found ScyllaDB nodes: $SCYLLA_IPS"
    break
  fi
  echo "Waiting for ScyllaDB nodes... (attempt $i/30)"
  sleep 10
done

if [ -z "$SCYLLA_IPS" ]; then
  echo "ERROR: No ScyllaDB nodes found after 5 minutes"
  exit 1
fi

# Generate scylla_servers.yml
cat << EOF > /home/ec2-user/scylla-monitoring-4.9.4/prometheus/scylla_servers.yml
- targets:
EOF

for ip in $SCYLLA_IPS; do
  echo "    - $ip" >> /home/ec2-user/scylla-monitoring-4.9.4/prometheus/scylla_servers.yml
done

cat << EOF >> /home/ec2-user/scylla-monitoring-4.9.4/prometheus/scylla_servers.yml
  labels:
    cluster: "unreal-cloud-ddc"
    dc: "${var.region}"
    region: "${var.region}"
EOF

echo "ScyllaDB monitoring configuration complete"

# Start monitoring stack
cd /home/ec2-user/scylla-monitoring-4.9.4
sudo ./start-all.sh -l -d /home/ec2-user/prometheus/data -a /home/ec2-user/prometheus/alertmanager
DISCOVERY_EOF

chmod +x /home/ec2-user/configure-scylla-monitoring.sh

# Run discovery script in background
nohup /home/ec2-user/configure-scylla-monitoring.sh > /var/log/scylla-monitoring-setup.log 2>&1 &

MONITORING_EOF

}
