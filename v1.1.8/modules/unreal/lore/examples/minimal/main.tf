provider "aws" {
  region = "us-west-2"
}

module "lore" {
  source = "../../"

  environment           = "dev"
  container_image       = var.container_image
  allowed_ingress_cidrs = var.allowed_ingress_cidrs

  # Dev-friendly: cheap instance, no NVMe requirement, no protection
  instance_type              = "i4i.xlarge"
  enable_deletion_protection = false
  enable_force_destroy       = true
  asg_desired_size           = 1
  auth_mode                  = "none"
}

