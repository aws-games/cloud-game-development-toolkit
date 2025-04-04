variables {
  root_domain_name = "henrykie.people.aws.dev"
}

run "teamcity-only" {
  assert {
    condition = module.teamcity.external_alb_dns_name != null
    error_message = "External ALB DNS name is null."
  }
}