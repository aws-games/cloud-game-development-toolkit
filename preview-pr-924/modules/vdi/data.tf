data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "workstation_subnets" {
  for_each = var.workstations
  id       = each.value.subnet_id
}

data "aws_region" "current" {}
