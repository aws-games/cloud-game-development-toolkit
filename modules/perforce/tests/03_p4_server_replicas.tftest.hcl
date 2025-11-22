run "replica_validation" {
  command = plan

  variables {
    route53_public_hosted_zone_name = "example.com"
  }

  module {
    source = "./examples/replica-single-region"
  }

  # Verify replica configuration is properly parsed
  assert {
    condition = length(keys(var.p4_server_replicas_config)) == 2
    error_message = "Should have exactly 2 replicas configured"
  }

  # Verify replica types are valid
  assert {
    condition = alltrue([
      for k, v in var.p4_server_replicas_config :
      contains(["standby", "readonly"], v.replica_type)
    ])
    error_message = "All replica types should be valid"
  }

  # Verify replica domains are generated correctly
  assert {
    condition = length(local.replica_domains) == 2
    error_message = "Should generate domains for all replicas"
  }
}