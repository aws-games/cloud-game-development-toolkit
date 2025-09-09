locals {
  project_prefix = "cgd"

  # VPC Configuration
  vpc_cidr_block = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"

  tags = {
    Environment      = "dev"
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "VDI"
    TeamSize         = "solo"
  }
}
