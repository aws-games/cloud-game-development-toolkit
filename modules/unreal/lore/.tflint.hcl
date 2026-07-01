tflint {
  required_version = ">= 0.50"
}

config {
  call_module_type    = "local"
  disabled_by_default = false
}

plugin "terraform" {
  enabled = true
  version = "0.10.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Terraform language rules
rule "terraform_naming_convention" { enabled = true }
rule "terraform_documented_variables" { enabled = true }
rule "terraform_documented_outputs" { enabled = true }
rule "terraform_unused_declarations" { enabled = true }
rule "terraform_standard_module_structure" { enabled = true }

# AWS best practice rules (opt-in)
# Disabled: fires false positives on module composition (sub-modules propagate
# tags via var.tags, but tflint can't trace variable->resource tag inheritance)
# rule "aws_resource_missing_tags" {
#   enabled = true
#   tags    = ["Project", "Environment"]
# }
