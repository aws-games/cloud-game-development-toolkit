data "aws_availability_zones" "available" {}

locals {
  # Simple Build Pipeline Configuration

  # IPV4 CIDR blocks that need Jenkins access. For example:
  # "<my personal ip>/32"
  allowlist = []

  # Jenkins and Build Farm Configurations
  jenkins_agent_secret_arns = []

  build_farm_compute = {
    /* Example Configuration
    graviton_builders : {
      ami           = "ami-0a1b2c3d4e5f"
      instance_type = "c7g.large"
    }
    windows_builders : {
      ami           = "ami-9z8y7x6w5v"
      instance_type = "c7a.large"
    }
    */
  }

  build_farm_fsx_openzfs_storage = {
    /* Example Configuration
    cache : {
      storage_type        = "SSD"
      throughput_capacity = 160
      storage_capacity    = 256
      deployment_type     = "MULTI_AZ_1"
      route_table_ids     = [aws_route_table.private_rt.id]
    }
    workspace : {
      storage_type        = "SSD"
      throughput_capacity = 160
      storage_capacity    = 564
      deployment_type     = "MULTI_AZ_1"
      route_table_ids     = [aws_route_table.private_rt.id]
    }
    */
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
