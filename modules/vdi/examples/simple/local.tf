# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Default VPC CIDR
  vpc_cidr_block = "10.0.0.0/16"

  # Public subnets will be used for load balancers and NAT gateways
  public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]

  # Private subnets will be used for VDI instances
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

  # Use the first n available AZs in the region
  azs = slice(data.aws_availability_zones.available.names, 0, length(local.private_subnet_cidrs))
  
  # Determine availability zones to use
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : local.azs

  # Common tags to be applied to all resources
  tags = merge({
    "Environment"    = var.environment
    "Project"        = "VDI-Example"
    "Owner"          = "DevOps-Team"
    "Purpose"        = "Development-Workstation"
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "VDI"
    "iac-provider"   = "Terraform"
  }, var.tags)

  # VPC Flow Logs settings
  enable_flow_logs        = false
  flow_logs_retention_days = 30
  flow_logs_traffic_type   = "ALL"
}
