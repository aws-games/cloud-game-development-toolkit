helix_authentication_service_certificate_arn = "arn:aws:acm:us-west-2:<REDACTED>:certificate/<REDACTED>"
helix_swarm_certificate_arn                  = "arn:aws:acm:us-west-2:<REDACTED>:certificate/<REDACTED>"
helix_swarm_environment_variables = {
  p4d_super_user_arn          = "arn:aws:ssm:us-west-2:<REDACTED>:parameter/p4d_super_user"
  p4d_super_user_password_arn = "arn:aws:ssm:us-west-2:<REDACTED>:parameter/p4d_super_user_password"
  p4d_swarm_user_arn          = "arn:aws:ssm:us-west-2:<REDACTED>:parameter/p4d_super_user"
  p4d_swarm_password_arn      = "arn:aws:ssm:us-west-2:<REDACTED>:parameter/p4d_super_user_password"
}
build_farm_compute = {
  windows_server_amd64 : {
    ami           = "ami-<REDACTED>"
    instance_type = "c7i.xlarge"
  }
  ubuntu_jammy_amd64 : {
    ami           = "ami-<REDACTED>"
    instance_type = "c7i.2xlarge"
  }
  ubuntu_jammy_arm64 : {
    ami           = "ami-<REDACTED>"
    instance_type = "c7gd.2xlarge"
  }
}

build_farm_fsx_openzfs_storage = {
  cache : {
    storage_type        = "SSD"
    throughput_capacity = 160
    storage_capacity    = 256
  }
  workspace : {
    storage_type        = "SSD"
    throughput_capacity = 160
    storage_capacity    = 564
  }
}
