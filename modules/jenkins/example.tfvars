vpc_id = "vpc-<id>"
jenkins_alb_subnets = [
  "subnet-<public-a>",
  "subnet-<public-b>"
]
jenkins_service_subnets = [
  "subnet-<private-a>",
  "subnet-<private-b>"
]
certificate_arn = "arn:aws:acm:<region>:<account-if>>:certificate/<cert-id>"

build_farm_subnets = [
  "subnet-<private-a>",
  "subnet-<private-b>"
]

existing_security_groups = [
  "sg-<id>"
]

artifact_buckets = {
  bucket1 = {
    name                 = "<bucket-name>"
    enable_force_destroy = true
  }
}

jenkins_agent_secret_arns = [
"arn:aws:secretsmanager:<region>:<account-id>:secret:<secret-name>"]

build_farm_compute = {
  windows = {
    ami               = "ami-<id>>"
    instance_type     = "c6a.4xlarge"
    ebs_optimized     = true
    enable_monitoring = true
  }
}

create_ec2_fleet_plugin_policy = true