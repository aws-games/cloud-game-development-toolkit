# run "setup" {
#   command = plan
#   module {
#     source = "./tests/setup"
#   }
# }

run "public_connectivity_test" {
  command = plan

  # variables {
  #   domain_name = run.setup.route53_public_hosted_zone_name
  # }

  module {
    source = "./examples/public-connectivity"
  }
}

# Unused until error handling/retry logic is improved in Terraform test
# https://github.com/hashicorp/terraform/issues/36846#issuecomment-2820247524
# run "e2e_test" {
#   command = apply
#   module {
#     source = "./examples/public-connectivity"
#   }
# }
