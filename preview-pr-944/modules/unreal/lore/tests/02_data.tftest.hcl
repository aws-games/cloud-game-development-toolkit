mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
}
mock_provider "tls" {}
mock_provider "random" {}

run "data_module_outputs_use_name_prefix" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    vpc_id                = null
    vpc_cidr              = "10.0.0.0/16"
    availability_zones    = ["us-east-1a", "us-east-1b"]
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
  }

  assert {
    condition     = module.data.fragments_table_name == "lore-dev-fragments"
    error_message = "Fragments table name should be lore-dev-fragments"
  }

  assert {
    condition     = module.data.fragment_metadata_table_name == "lore-dev-fragment-metadata"
    error_message = "Fragment metadata table name should be lore-dev-fragment-metadata"
  }

  assert {
    condition     = module.data.mutable_store_table_name == "lore-dev-mutable-typed-store"
    error_message = "Mutable store table name should be lore-dev-mutable-typed-store"
  }

  assert {
    condition     = module.data.locks_table_name == "lore-dev-locks"
    error_message = "Locks table name should be lore-dev-locks"
  }
}
