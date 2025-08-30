data "aws_caller_identity" "current" {}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}