plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "opa" {
  enabled = true
  version = "0.7.0"
  source  = "github.com/terraform-linters/tflint-ruleset-opa"
}