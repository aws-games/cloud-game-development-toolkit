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
    route53_public_hosted_zone_name = run.setup.route53_public_hosted_zone_name
  }
  module {
    source = "./examples/create-resources-complete"
  }
}

# Unused until error handling/retry logic is improved in Terraform test
# https://github.com/hashicorp/terraform/issues/36846#issuecomment-2820247524
# run "e2e_test" {
#   command = apply
#   module {
#     source = "./examples/create-resources-complete"
#   }
# }
