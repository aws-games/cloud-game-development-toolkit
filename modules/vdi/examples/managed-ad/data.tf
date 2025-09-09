# Auto-detect current IP
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for current region
data "aws_region" "current" {}