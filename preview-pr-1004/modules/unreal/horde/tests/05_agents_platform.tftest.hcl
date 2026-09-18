# Test: Agent AMI platform gating for the Linux SSM enrollment association
#
# These tests cover the fix in asg.tf where the Linux enrollment SSM
# association (aws_ssm_association.configure_unreal_horde_agent) must be SKIPPED
# on an all-Windows agent fleet. The association targets only Linux launch
# templates (AMI platform == ""); on an all-Windows fleet that target list is
# empty and AWS rejects CreateAssociation with "Tag or InstanceIds values cannot
# be empty." The module now gates the association with:
#   count = length(var.agents) > 0 && local.linux_agent_count > 0 ? 1 : 0
# where local.linux_agent_count counts agent pools whose AMI platform == "".
#
# This is a SEPARATE file from 04_agents.tftest.hcl on purpose: the aws_ami
# mock's `platform` default is file-wide (one value for every aws_ami lookup),
# so we cannot both set a deterministic platform here and leave 04's existing
# runs on their current (platform-agnostic) path. Keeping these runs isolated
# lets us pin platform per-file without changing 04's resource counts.
#
# Mock providers must be duplicated in each test file (Terraform limitation).

# ---------------------------------------------------------------------------
# All-Windows fleet: mock aws_ami.platform = "windows"
# ---------------------------------------------------------------------------
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
      id   = "us-east-1"
    }
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
      arn                 = "arn:aws:ecs:us-east-1:123456789012:cluster/test"
      id                  = "test"
      name                = "test"
      status              = "ACTIVE"
      pending_tasks_count = 0
      running_tasks_count = 0
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = <<-EOT
        {
          "Version": "2012-10-17",
          "Statement": [{
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
          }]
        }
      EOT
    }
  }

  # Pin the agent AMI platform so the Linux/Windows gate is deterministic.
  # "windows" -> Windows agents (configured via user_data, no SSM association).
  mock_data "aws_ami" {
    defaults = {
      platform = "windows"
    }
  }
}

# Mock random provider
mock_provider "random" {}

# Test: All-Windows agent fleet must NOT create the Linux SSM association.
# Mirrors the iSCSI/NTFS SAN pipeline sample (sync-agent + build-agent pools).
run "unit_test_all_windows_agents_no_ssm_association" {
  command = plan

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-win"

    # Two Windows agent pools
    agents = {
      "sync-agent" = {
        ami             = "ami-win00000001"
        instance_type   = "c5.2xlarge"
        horde_pool_name = "win-sync"
        block_device_mappings = [
          {
            device_name = "/dev/sda1"
            ebs = {
              volume_size = 100
            }
          }
        ]
        min_size = 1
        max_size = 2
      }
      "build-agent" = {
        ami             = "ami-win00000002"
        instance_type   = "c5.4xlarge"
        horde_pool_name = "win-build"
        block_device_mappings = [
          {
            device_name = "/dev/sda1"
            ebs = {
              volume_size = 200
            }
          }
        ]
        min_size = 1
        max_size = 4
      }
    }

    enable_new_agents_by_default = true
  }

  # The Linux enrollment association must be SKIPPED for an all-Windows fleet.
  assert {
    condition     = length(aws_ssm_association.configure_unreal_horde_agent) == 0
    error_message = "SSM enrollment association must NOT be created for an all-Windows agent fleet"
  }

  # Launch templates are still created (one per pool) - Windows is configured
  # via user_data, not the SSM association.
  assert {
    condition     = length(aws_launch_template.unreal_horde_agent_template) == 2
    error_message = "Launch templates should still be created for each Windows agent pool"
  }

  # local.linux_agent_count should be 0 when every pool is Windows.
  assert {
    condition     = local.linux_agent_count == 0
    error_message = "linux_agent_count should be 0 when all agent AMIs report platform == windows"
  }
}

# ---------------------------------------------------------------------------
# Linux fleet: mock aws_ami.platform = "" (Linux)
# ---------------------------------------------------------------------------
mock_provider "aws" {
  alias = "linux"

  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
      id   = "us-east-1"
    }
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
      arn                 = "arn:aws:ecs:us-east-1:123456789012:cluster/test"
      id                  = "test"
      name                = "test"
      status              = "ACTIVE"
      pending_tasks_count = 0
      running_tasks_count = 0
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = <<-EOT
        {
          "Version": "2012-10-17",
          "Statement": [{
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
          }]
        }
      EOT
    }
  }

  # Linux AMIs report an empty platform ("").
  mock_data "aws_ami" {
    defaults = {
      platform = ""
    }
  }
}

# Test: Linux agent fleet DOES create the SSM enrollment association.
# Proves the gate does not over-suppress the association.
run "unit_test_linux_agents_create_ssm_association" {
  command = plan

  providers = {
    aws = aws.linux
  }

  variables {
    vpc_id                            = "vpc-12345678"
    unreal_horde_service_subnets      = ["subnet-123", "subnet-456"]
    unreal_horde_internal_alb_subnets = ["subnet-123", "subnet-456"]
    certificate_arn                   = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    fully_qualified_domain_name       = "horde.example.com"

    create_external_alb = false
    create_internal_alb = true
    name                = "horde-lin"

    # Single Linux agent pool
    agents = {
      "linux-build" = {
        ami             = "ami-lin00000001"
        instance_type   = "c5.2xlarge"
        horde_pool_name = "linux-build"
        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 100
            }
          }
        ]
        min_size = 1
        max_size = 5
      }
    }

    enable_new_agents_by_default = true
  }

  # The Linux enrollment association MUST be created for a Linux fleet.
  assert {
    condition     = length(aws_ssm_association.configure_unreal_horde_agent) == 1
    error_message = "SSM enrollment association should be created for a Linux agent fleet"
  }

  # local.linux_agent_count should be 1 for the single Linux pool.
  assert {
    condition     = local.linux_agent_count == 1
    error_message = "linux_agent_count should be 1 for a single Linux agent pool"
  }
}
