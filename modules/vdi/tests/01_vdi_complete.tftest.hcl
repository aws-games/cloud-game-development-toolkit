# Fetch relevant values from SSM Parameter Store
run "setup" {
  command = plan
  module {
    source = "./tests/setup"
  }
}

run "unit_test" {
  command = plan

  variables {
    domain_name                 = run.setup.route53_public_hosted_zone_name
    directory_name              = run.setup.directory_name
    directory_admin_password    = run.setup.directory_admin_password
  }

  module {
    source = "./examples/create-resources-complete"
  }

  # Test that VDI instances are created with correct configuration
  assert {
    condition     = length(module.vdi.instance_ids) == 3
    error_message = "Expected 3 VDI instances to be created (TroyWood, MerleSmith, and LouPierce)"
  }

  # Test that public IPs are assigned
  assert {
    condition     = length(module.vdi.public_ips) > 0
    error_message = "Expected public IPs to be assigned to VDI instances"
  }

  # Test that private IPs are assigned
  assert {
    condition     = length(module.vdi.private_ips) == 3
    error_message = "Expected private IPs to be assigned to VDI instances"
  }

  # Test that IAM instance profile is created
  assert {
    condition     = module.vdi.iam_instance_profile != null
    error_message = "Expected IAM instance profile to be created"
  }
}

# Unused until error handling/retry logic is improved in Terraform test
# https://github.com/hashicorp/terraform/issues/36846#issuecomment-2820247524
# run "e2e_test" {
#   command = apply
#   module {
#     source = "./examples"
#   }
# }
