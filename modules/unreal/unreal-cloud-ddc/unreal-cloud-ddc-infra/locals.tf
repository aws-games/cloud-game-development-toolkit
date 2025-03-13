
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
}
