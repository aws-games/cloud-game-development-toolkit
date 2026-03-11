# Test: Shared Resources Creation Logic
# This test validates that shared resources (ECS cluster, load balancers, Route53, S3)
# are created correctly based on the submodules deployed

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
      arn  = "arn:aws:ecs:us-east-1:123456789012:cluster/existing-cluster"
      id   = "existing-cluster"
      name = "existing-cluster"
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

# Test 1: ECS cluster created when only Auth is deployed
run "ecs_cluster_auth_only" {
  command = plan

  variables {
    vpc_id                              = "vpc-12345678"
    shared_alb_subnets                  = ["subnet-111", "subnet-222"]
    certificate_arn                     = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    create_shared_network_load_balancer = false
    create_route53_private_hosted_zone  = false

    p4_auth_config = {
      fully_qualified_domain_name = "auth.test.internal"
      service_subnets             = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when P4 Auth is deployed"
  }

  assert {
    condition     = local.create_shared_ecs_cluster == true
    error_message = "create_shared_ecs_cluster should be true when Auth is deployed and no existing cluster provided"
  }
}

# Test 2: ECS cluster created when only Code Review is deployed
run "ecs_cluster_code_review_only" {
  command = plan

  variables {
    vpc_id                              = "vpc-12345678"
    shared_alb_subnets                  = ["subnet-111", "subnet-222"]
    certificate_arn                     = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    create_shared_network_load_balancer = false
    create_route53_private_hosted_zone  = false

    p4_code_review_config = {
      fully_qualified_domain_name = "swarm.test.internal"
      service_subnets             = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "ECS cluster should be created when P4 Code Review is deployed"
  }

  assert {
    condition     = local.create_shared_ecs_cluster == true
    error_message = "create_shared_ecs_cluster should be true when Code Review is deployed and no existing cluster provided"
  }
}

# Test 3: Single ECS cluster shared by both Auth and Code Review
run "ecs_cluster_shared" {
  command = plan

  variables {
    vpc_id                              = "vpc-12345678"
    shared_alb_subnets                  = ["subnet-111", "subnet-222"]
    certificate_arn                     = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    shared_ecs_cluster_name             = "my-shared-cluster"
    create_shared_network_load_balancer = false
    create_route53_private_hosted_zone  = false

    p4_auth_config = {
      fully_qualified_domain_name = "auth.test.internal"
      service_subnets             = ["subnet-111", "subnet-222"]
    }

    p4_code_review_config = {
      fully_qualified_domain_name = "swarm.test.internal"
      service_subnets             = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 1
    error_message = "Only one ECS cluster should be created for both services"
  }

  assert {
    condition     = aws_ecs_cluster.perforce_web_services_cluster[0].name == "my-shared-cluster"
    error_message = "ECS cluster name should match the configured shared_ecs_cluster_name"
  }
}

# Test 4: Route53 private hosted zone and records
run "route53_private_zone" {
  command = plan

  variables {
    vpc_id                             = "vpc-12345678"
    shared_nlb_subnets                 = ["subnet-111", "subnet-222"]
    shared_alb_subnets                 = ["subnet-111", "subnet-222"]
    certificate_arn                    = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    create_route53_private_hosted_zone = true
    route53_private_hosted_zone_name   = "perforce.internal"

    p4_server_config = {
      fully_qualified_domain_name = "perforce.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
    }

    p4_auth_config = {
      fully_qualified_domain_name = "auth.perforce.internal"
      service_subnets             = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = length(aws_route53_zone.perforce_private_hosted_zone) == 1
    error_message = "Route53 private hosted zone should be created when enabled"
  }

  assert {
    condition     = aws_route53_zone.perforce_private_hosted_zone[0].name == "perforce.internal"
    error_message = "Route53 zone name should match the configured name"
  }
}

# Test 5: Load balancer access logs with S3 bucket
run "load_balancer_access_logs" {
  command = plan

  variables {
    vpc_id                             = "vpc-12345678"
    shared_nlb_subnets                 = ["subnet-111", "subnet-222"]
    shared_alb_subnets                 = ["subnet-111", "subnet-222"]
    certificate_arn                    = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    enable_shared_lb_access_logs       = true
    create_route53_private_hosted_zone = false

    p4_server_config = {
      fully_qualified_domain_name = "p4.test.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
    }

    p4_auth_config = {
      fully_qualified_domain_name = "auth.test.internal"
      service_subnets             = ["subnet-111", "subnet-222"]
    }
  }

  assert {
    condition     = length(aws_s3_bucket.shared_lb_access_logs_bucket) == 1
    error_message = "S3 bucket should be created when load balancer access logging is enabled"
  }

  assert {
    condition     = aws_lb.perforce[0].enable_cross_zone_load_balancing == true
    error_message = "NLB should have cross-zone load balancing enabled"
  }
}

# Test 6: No ECS cluster when only P4 Server is deployed
run "no_ecs_cluster_server_only" {
  command = plan

  variables {
    vpc_id                                  = "vpc-12345678"
    shared_nlb_subnets                      = ["subnet-111", "subnet-222"]
    certificate_arn                         = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    create_shared_application_load_balancer = false
    create_route53_private_hosted_zone      = false

    p4_server_config = {
      fully_qualified_domain_name = "p4.test.internal"
      instance_subnet_id          = "subnet-111"
      p4_server_type              = "p4d_commit"
    }
  }

  assert {
    condition     = length(aws_ecs_cluster.perforce_web_services_cluster) == 0
    error_message = "ECS cluster should not be created when only P4 Server (non-ECS service) is deployed"
  }

  assert {
    condition     = local.create_shared_ecs_cluster == false
    error_message = "create_shared_ecs_cluster should be false when only P4 Server is deployed"
  }
}
