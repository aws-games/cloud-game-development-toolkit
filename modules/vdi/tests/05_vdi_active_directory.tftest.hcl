# Test VDI Active Directory integration
run "setup" {
  command = plan
  module {
    source = "./tests/setup"
  }
}

run "ad_integration_test" {
  command = plan

  variables {
    directory_admin_password = run.setup.directory_admin_password
    directory_name          = run.setup.directory_name

    # Test AD integration settings
    directory_edition = "Standard"
  }

  module {
    source = "./examples/create-resources-complete"
  }

  # Test that VDI instances are created with AD integration
  assert {
    condition     = length(module.vdi.instance_ids) > 0
    error_message = "Expected VDI instances to be created with AD integration"
  }

  # Test that IAM instance profile is created (needed for AD operations)
  assert {
    condition     = module.vdi.iam_instance_profile != null
    error_message = "Expected IAM instance profile to be created for AD operations"
  }

  # Test that private keys are available (needed for AD domain join)
  assert {
    condition     = length(module.vdi.private_keys) > 0
    error_message = "Expected private keys to be available for AD domain join operations"
  }
}

run "ad_enterprise_edition_test" {
  command = plan

  variables {
    directory_admin_password = run.setup.directory_admin_password
    directory_name          = run.setup.directory_name
    directory_edition       = "Enterprise"
  }

  module {
    source = "./examples/create-resources-complete"
  }

  # Test that VDI instances are created with Enterprise AD
  assert {
    condition     = length(module.vdi.instance_ids) > 0
    error_message = "Expected VDI instances to be created with Enterprise AD integration"
  }
}

run "ad_user_creation_test" {
  command = plan

  variables {
    directory_admin_password = run.setup.directory_admin_password
    directory_name          = run.setup.directory_name
  }

  module {
    source = "./examples/create-resources-complete"
  }

  # Test that VDI instances are created for AD users
  assert {
    condition     = length(module.vdi.instance_ids) > 0
    error_message = "Expected VDI instances to be created for AD users"
  }

  # Test that private IPs are assigned (needed for AD communication)
  assert {
    condition     = length(module.vdi.private_ips) > 0
    error_message = "Expected private IPs to be assigned for AD communication"
  }
}
