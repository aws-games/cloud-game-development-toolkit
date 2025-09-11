# Data sources for existing infrastructure
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for availability zones (used for fallback AZ selection)
data "aws_availability_zones" "available" {
  state = "available"
}





# Data sources for subnet AZ lookup (like Perforce module)
data "aws_subnet" "workstation_subnets" {
  for_each = var.workstations
  id       = each.value.subnet_id
}
