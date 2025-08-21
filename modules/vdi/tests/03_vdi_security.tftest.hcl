# Test VDI security configurations
run "setup" {
  command = plan
  module {
    source = "./tests/setup"
  }
}

run "security_groups_test" {
  command = plan

  variables {
    directory_admin_password = run.setup.directory_admin_password
    directory_name          = run.setup.directory_name
  }

  module {
    source = "./examples/create-resources-complete"
  }

  # Test that VDI instances are created
  assert {
    condition     = length(module.vdi.instance_ids) > 0
    error_message = "Expected VDI instances to be created"
  }

  # Test that public IPs are assigned (indicates security groups allow access)
  assert {
    condition     = length(module.vdi.public_ips) > 0
    error_message = "Expected public IPs to be assigned to VDI instances"
  }
}

run "key_pair_test" {
  command = plan

  variables {
    directory_admin_password = run.setup.directory_admin_password
    directory_name          = run.setup.directory_name
  }

  module {
    source = "./examples/create-resources-complete"
  }

  # Test that private keys are created (indicates key pairs were created)
  assert {
    condition     = length(module.vdi.private_keys) > 0
    error_message = "Expected private keys to be created for VDI instances"
  }
}

run "secrets_manager_test" {
  command = plan

  variables {
    directory_admin_password = run.setup.directory_admin_password
    directory_name          = run.setup.directory_name
  }

  module {
    source = "./examples/create-resources-complete"
  }

  # Test that IAM instance profile is created (needed for secrets access)
  assert {
    condition     = module.vdi.iam_instance_profile != null
    error_message = "Expected IAM instance profile to be created for secrets access"
  }

  # Test that VDI instances are created
  assert {
    condition     = length(module.vdi.instance_ids) > 0
    error_message = "Expected VDI instances to be created"
  }
}
