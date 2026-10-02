mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1" }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "archive" {}

# =============================================================================
# X-Ray smoke test enabled (default)
# =============================================================================

run "xray_smoke_test_enabled_by_default" {
  command = plan

  variables {
    project_prefix        = "lore"
    environment           = "dev"
    container_image       = "placeholder:latest"
    allowed_ingress_cidrs = ["10.0.0.0/8"]
  }
}

# =============================================================================
# X-Ray smoke test disabled
# =============================================================================

run "xray_smoke_test_disabled_plans_successfully" {
  command = plan

  variables {
    project_prefix         = "lore"
    environment            = "dev"
    container_image        = "placeholder:latest"
    allowed_ingress_cidrs  = ["10.0.0.0/8"]
    enable_xray_smoke_test = false
  }
}
