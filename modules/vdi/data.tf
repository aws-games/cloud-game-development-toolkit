# Data sources for existing infrastructure
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Data sources for subnet AZ lookup (like Perforce module)
data "aws_subnet" "workstation_subnets" {
  for_each = var.workstations
  id       = each.value.subnet_id
}

# Data source for default region
data "aws_region" "current" {}
