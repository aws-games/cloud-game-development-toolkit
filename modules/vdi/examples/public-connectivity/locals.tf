locals {
  project_prefix = "cgd"

  # VPC Configuration
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"

  tags = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "vdi-local-only-example"
    "ModuleName"     = "terraform-aws-vdi"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/vdi"
    "Environment"    = "dev"
    "TeamSize"       = "solo"
  }
}
