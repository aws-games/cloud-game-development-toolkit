########################################
# General
########################################
variable "project_prefix" {
  type        = string
  description = "The project prefix for this workload. This is appended to the beginning of most resource names."
  default     = "cgd"

  validation {
    condition     = length(var.project_prefix) > 1 && length(var.project_prefix) <= 10
    error_message = "The defined 'project_prefix' has too many characters (${length(var.project_prefix)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }
}



########################################
# Networking
########################################
variable "vpc_ids" {
  description = "Map of VPC IDs for each region"
  type        = map(string)
  
  validation {
    condition     = contains(keys(var.vpc_ids), "primary")
    error_message = "Must specify a primary VPC ID."
  }
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the Unreal Cloud DDC load balancers."
  default     = []
}

########################################
# Infrastructure Configuration
########################################
variable "infrastructure_config" {
  type = object({
    # General
    name           = optional(string, "unreal-cloud-ddc")
    project_prefix = optional(string, "cgd")
    environment    = optional(string, "dev")
    region         = optional(string, null)
    debug          = optional(bool, false)

    # EKS Configuration
    kubernetes_version      = optional(string, "1.31")
    eks_node_group_subnets = optional(list(string), [])
    
    # Node Groups
    nvme_managed_node_instance_type   = optional(string, "i3en.large")
    nvme_managed_node_desired_size    = optional(number, 2)
    nvme_managed_node_max_size        = optional(number, 2)
    nvme_managed_node_min_size        = optional(number, 1)
    
    worker_managed_node_instance_type = optional(string, "c5.large")
    worker_managed_node_desired_size  = optional(number, 1)
    worker_managed_node_max_size      = optional(number, 1)
    worker_managed_node_min_size      = optional(number, 0)
    
    system_managed_node_instance_type = optional(string, "m5.large")
    system_managed_node_desired_size  = optional(number, 1)
    system_managed_node_max_size      = optional(number, 2)
    system_managed_node_min_size      = optional(number, 1)

    # ScyllaDB Configuration
    scylla_subnets                    = optional(list(string), [])
    scylla_ami_name                   = optional(string, "ScyllaDB 6.0.1")
    scylla_instance_type              = optional(string, "i4i.2xlarge")
    scylla_architecture               = optional(string, "x86_64")
    scylla_db_storage                 = optional(number, 100)
    scylla_db_throughput              = optional(number, 200)
    create_scylla_monitoring_stack    = optional(bool, true)
    scylla_monitoring_instance_type   = optional(string, "t3.xlarge")
    scylla_monitoring_instance_storage = optional(number, 20)

    # Load Balancer Configuration
    create_application_load_balancer             = optional(bool, true)
    internal_facing_application_load_balancer    = optional(bool, false)
    monitoring_application_load_balancer_subnets = optional(list(string), null)
    alb_certificate_arn                          = optional(string, null)
    enable_scylla_monitoring_lb_deletion_protection = optional(bool, false)
    enable_scylla_monitoring_lb_access_logs         = optional(bool, false)
    scylla_monitoring_lb_access_logs_bucket         = optional(string, null)
    scylla_monitoring_lb_access_logs_prefix         = optional(string, null)

    # EKS Access Configuration
    eks_cluster_public_endpoint_access_cidr = optional(list(string), [])
    eks_cluster_public_access               = optional(bool, false)
    eks_cluster_private_access              = optional(bool, true)
  })

  description = <<EOT
    Configuration object for Unreal Cloud DDC infrastructure components (EKS, ScyllaDB, Load Balancers).
    
    # General
    name: "The string included in the naming of resources related to Unreal Cloud DDC. Default is 'unreal-cloud-ddc'"
    project_prefix: "The project prefix for this workload. This is appended to the beginning of most resource names."
    environment: "The current environment (e.g. dev, prod, etc.)"
    region: "The AWS region to deploy to"
    debug: "Enable debug mode"

    # EKS Configuration
    kubernetes_version: "Kubernetes version to be used by the EKS cluster."
    eks_node_group_subnets: "A list of subnets ids you want the EKS nodes to be installed into. Private subnets are strongly recommended."

    # ScyllaDB Configuration
    scylla_subnets: "A list of subnet IDs where Scylla will be deployed. Private subnets are strongly recommended."
    scylla_instance_type: "The type and size of the Scylla instance."
    scylla_architecture: "The chip architecture to use when finding the scylla image."

    # Load Balancer Configuration
    create_application_load_balancer: "Whether to create an application load balancer for the Scylla monitoring dashboard."
    monitoring_application_load_balancer_subnets: "The subnets in which the ALB will be deployed"
    alb_certificate_arn: "The ARN of the certificate to use on the ALB"
  EOT

  validation {
    condition     = var.infrastructure_config.scylla_architecture == "arm64" || var.infrastructure_config.scylla_architecture == "x86_64"
    error_message = "The infrastructure_config.scylla_architecture variable must be either 'arm64' or 'x86_64'."
  }

  validation {
    condition     = contains(["i8g", "i7ie", "i4g", "i4i", "im4gn", "is4gen", "i4i", "i3", "i3en"], split(".", var.infrastructure_config.scylla_instance_type)[0])
    error_message = "Must be an instance family that contains NVME"
  }
}

########################################
# Application Configuration
########################################
variable "application_config" {
  type = object({
    # General
    name           = optional(string, "unreal-cloud-ddc")
    project_prefix = optional(string, "cgd")

    # Cluster Configuration
    cluster_name              = optional(string, null)
    cluster_oidc_provider_arn = optional(string, null)

    # Application Settings
    unreal_cloud_ddc_namespace           = optional(string, "unreal-cloud-ddc")
    unreal_cloud_ddc_version             = optional(string, "1.2.0")
    unreal_cloud_ddc_service_account_name = optional(string, "unreal-cloud-ddc-sa")
    unreal_cloud_ddc_helm_values         = optional(list(string), [])

    # Credentials
    ghcr_credentials_secret_manager_arn = string
    oidc_credentials_secret_manager_arn = optional(string, null)

    # Certificate Management
    certificate_manager_hosted_zone_arn = optional(list(string), [])
    enable_certificate_manager          = optional(bool, false)

    # S3 Configuration
    s3_bucket_id = optional(string, null)
  })

  description = <<EOT
    Configuration object for Unreal Cloud DDC application components (Helm charts, Kubernetes resources).
    
    # General
    name: "The string included in the naming of resources related to Unreal Cloud DDC applications."
    project_prefix: "The project prefix for this workload."

    # Application Settings
    unreal_cloud_ddc_namespace: "Namespace for Unreal Cloud DDC"
    unreal_cloud_ddc_version: "Version of the Unreal Cloud DDC Helm chart."
    unreal_cloud_ddc_helm_values: "List of YAML files for Unreal Cloud DDC"

    # Credentials
    ghcr_credentials_secret_manager_arn: "ARN for credentials stored in secret manager. Needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache."
    oidc_credentials_secret_manager_arn: "ARN for oidc credentials stored in secret manager."

    # Certificate Management
    enable_certificate_manager: "Enable Certificate Manager for Ingress. Required for TLS termination."
    certificate_manager_hosted_zone_arn: "ARN of the Certificate Manager for Ingress."
  EOT

  validation {
    condition     = length(regexall("ecr-pullthroughcache/", var.application_config.ghcr_credentials_secret_manager_arn)) > 0
    error_message = "ghcr_credentials_secret_manager_arn needs to be prefixed with 'ecr-pullthroughcache/' to be compatible with ECR pull through cache."
  }

  validation {
    condition     = var.application_config.enable_certificate_manager ? length(var.application_config.certificate_manager_hosted_zone_arn) > 0 : true
    error_message = "Certificate Manager hosted zone ARN is required when enable_certificate_manager is true."
  }
}

########################################
# Multi-Region Configuration
########################################
variable "regions" {
  description = "Map of regions to deploy Unreal Cloud DDC infrastructure"
  type = map(object({
    region = string
  }))
  
  validation {
    condition     = contains(keys(var.regions), "primary")
    error_message = "Must specify a primary region in the regions map."
  }
  
  validation {
    condition     = length(var.regions) <= 2
    error_message = "Currently supports maximum of 2 regions (primary and secondary)."
  }

  default = null
}

########################################
# Tags
########################################
variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "-"
    "ModuleName"     = "terraform-aws-unreal-cloud-ddc"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/unreal/unreal-cloud-ddc"
  }
}