locals {
  project_prefix = "cgd"

  # VPC Configuration
  vpc_cidr_block      = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24" # For NAT Gateway
  private_subnet_cidr = "10.0.2.0/24" # For VDI instances

  tags = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "vdi-private-connectivity-example"
    "ModuleName"     = "terraform-aws-vdi"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi"
    "Environment"    = "dev"
    "TeamSize"       = "solo"
  }
}
