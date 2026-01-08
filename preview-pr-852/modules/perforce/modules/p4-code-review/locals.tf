locals {
  # AMI selection: use provided ami_id or auto-detect latest Packer-built AMI
  selected_ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.p4_code_review[0].id

  # Module identifier for resource tagging
  module_identifier = "${var.project_prefix}-${var.name}"
  name_prefix       = "${var.project_prefix}-${var.name}"

  # Application configuration
  application_port = var.application_port

  # ElastiCache Redis configuration
  elasticache_redis_port                 = 6379
  elasticache_redis_engine_version       = "7.0"
  elasticache_redis_parameter_group_name = "default.redis7"

  # EC2 and EBS configuration
  ebs_availability_zone = var.ebs_availability_zone != null ? var.ebs_availability_zone : data.aws_subnet.instance_subnet.availability_zone
  host_data_path        = "/opt/perforce/swarm/data"
  ebs_device_name       = "/dev/xvdf"
}
