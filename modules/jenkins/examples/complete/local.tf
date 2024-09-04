data "aws_availability_zones" "available" {}


locals {
  # Simple Build Pipeline Configuration
  fully_qualified_domain_name = "example.com" # update this to the root domain name you own

  # IPV4 CIDR blocks that need Jenkins access. For example:
  # "<my personal ip>/32"

  # tflint-ignore: terraform_unused_declarations
  allowlist = []

  # Jenkins and Build Farm Configurations
  jenkins_agent_secret_arns = []

  build_farm_compute = {
    example_builders : {
      ami           = "ami-066784287e358dad1" // Amazon Linux 2023 (64-bit x86)
      instance_type = "t3.medium"
    }
  }

  build_farm_fsx_openzfs_storage = {
    cache : {
      storage_type        = "SSD"
      throughput_capacity = 160
      storage_capacity    = 256
      deployment_type     = "MULTI_AZ_1"
      route_table_ids     = [aws_route_table.private_rt.id]
    }
  }

  # VPC Configuration
  vpc_cidr_block       = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

  tags = {
    environment = "cgd"
  }
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}
