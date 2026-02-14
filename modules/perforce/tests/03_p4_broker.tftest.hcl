# Test: P4 Broker Conditional Creation and Resource Validation
# This test validates that the P4 Broker submodule is correctly created or skipped
# based on provided configuration, and that related shared resources behave correctly.

# Mock providers (required in each test file)
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { name = "us-east-1", id = "us-east-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDACKCEVSQ6C2EXAMPLE"
    }
  }
  mock_data "aws_elb_service_account" {
    defaults = {
      arn = "arn:aws:iam::127311923021:root"
      id  = "127311923021"
    }
  }
  mock_data "aws_ecs_cluster" {
    defaults = {
      arn                 = "arn:aws:ecs:us-east-1:123456789012:cluster/existing-cluster"
      id                  = "existing-cluster"
      name                = "existing-cluster"
      status              = "ACTIVE"
      pending_tasks_count = 0
      running_tasks_count = 0
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"*\",\"Resource\":\"*\"}]}"
    }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0", architecture = "x86_64" }
  }
}

mock_provider "awscc" {}
mock_provider "random" {}
mock_provider "null" {}
mock_provider "local" {}
mock_provider "netapp-ontap" {}

# Test 1: P4 Broker NOT created when config is null
run "broker_not_created_when_null" {
  command = plan

  variables {
    vpc_id                                  = "vpc-12345678"
    create_shared_network_load_balancer     = false
    create_shared_application_load_balancer = false
    create_route53_private_hosted_zone      = false
    # p4_broker_config is null by default
  }

  assert {
    condition     = length(module.p4_broker) == 0
    error_message = "P4 Broker submodule should not be created when p4_broker_config is null"
  }
}

# Test 2: P4 Broker created when config is provided
run "broker_created_when_configured" {
  command = plan

  variables {
    vpc_id                                  = "vpc-12345678"
    shared_nlb_subnets                      = ["subnet-111", "subnet-222"]
    create_shared_application_load_balancer = false
    create_route53_private_hosted_zone      = false

    p4_broker_config = {
      container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/p4-broker:latest"
      p4_target       = "ssl:p4server:1666"
      service_subnets = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = length(module.p4_broker) == 1
    error_message = "P4 Broker submodule should be created when p4_broker_config is provided"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when P4 Broker is deployed"
  }
}

# Test 3: Shared ECS cluster created when only broker is configured
run "ecs_cluster_broker_only" {
  command = plan

  variables {
    vpc_id                                  = "vpc-12345678"
    shared_nlb_subnets                      = ["subnet-111", "subnet-222"]
    create_shared_application_load_balancer = false
    create_route53_private_hosted_zone      = false

    p4_broker_config = {
      container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/p4-broker:latest"
      p4_target       = "ssl:p4server:1666"
      service_subnets = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = local.create_shared_ecs_cluster == true
    error_message = "create_shared_ecs_cluster should be true when P4 Broker is deployed and no existing cluster provided"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "Shared ECS cluster should be created when only P4 Broker is deployed"
  }
}

# Test 4: NLB listener created for broker traffic
run "nlb_listener_created_for_broker" {
  command = plan

  variables {
    vpc_id                                  = "vpc-12345678"
    shared_nlb_subnets                      = ["subnet-111", "subnet-222"]
    create_shared_application_load_balancer = false
    create_route53_private_hosted_zone      = false

    p4_broker_config = {
      container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/p4-broker:latest"
      p4_target       = "ssl:p4server:1666"
      service_subnets = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = length(aws_lb_listener.perforce_broker) == 1
    error_message = "NLB TCP listener should be created for P4 Broker traffic"
  }
}

# Test 5: P4 Broker with existing ECS cluster
run "broker_with_existing_cluster" {
  command = plan

  variables {
    vpc_id                                  = "vpc-12345678"
    shared_nlb_subnets                      = ["subnet-111", "subnet-222"]
    existing_ecs_cluster_name               = "my-existing-cluster"
    create_shared_application_load_balancer = false
    create_route53_private_hosted_zone      = false

    p4_broker_config = {
      container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/p4-broker:latest"
      p4_target       = "ssl:p4server:1666"
      service_subnets = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = length(module.p4_broker) == 1
    error_message = "P4 Broker submodule should be created when p4_broker_config is provided"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 0
    error_message = "ECS cluster should not be created when existing_ecs_cluster_name is provided"
  }

  assert {
    condition     = local.create_shared_ecs_cluster == false
    error_message = "create_shared_ecs_cluster should be false when existing cluster is provided"
  }
}

# Test 6: Full stack with broker
run "full_stack_with_broker" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    shared_nlb_subnets = ["subnet-111", "subnet-222", "subnet-333"]
    shared_alb_subnets = ["subnet-111", "subnet-222", "subnet-333"]
    certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert"

    create_route53_private_hosted_zone = true
    route53_private_hosted_zone_name   = "perforce.internal"

    p4_server_config = {
      fully_qualified_domain_name = "perforce.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
      depot_volume_size           = 128
      metadata_volume_size        = 32
      logs_volume_size            = 32
    }

    p4_auth_config = {
      fully_qualified_domain_name = "auth.perforce.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
    }

    p4_code_review_config = {
      fully_qualified_domain_name = "swarm.perforce.internal"
      service_subnets             = ["subnet-111", "subnet-222", "subnet-333"]
      enable_sso                  = true
    }

    p4_broker_config = {
      container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/p4-broker:latest"
      p4_target       = "ssl:p4.perforce.internal:1666"
      service_subnets = ["subnet-111", "subnet-222", "subnet-333"]
    }
  }

  assert {
    condition     = length(module.p4_server) == 1
    error_message = "P4 Server submodule should be created when p4_server_config is provided"
  }

  assert {
    condition     = length(module.p4_auth) == 1
    error_message = "P4 Auth submodule should be created when p4_auth_config is provided"
  }

  assert {
    condition     = length(module.p4_code_review) == 1
    error_message = "P4 Code Review submodule should be created when p4_code_review_config is provided"
  }

  assert {
    condition     = length(module.p4_broker) == 1
    error_message = "P4 Broker submodule should be created when p4_broker_config is provided"
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when web services are deployed"
  }
}
