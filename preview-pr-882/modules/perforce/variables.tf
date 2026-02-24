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
# Compute
########################################

# If an existing cluster is provided this will be used to run any ECS compatible services (Auth, Review)
variable "existing_ecs_cluster_name" {
  type        = string
  description = "The name of an existing ECS cluster to use for the Perforce server. If omitted a new cluster will be created."
  default     = null
}

variable "shared_ecs_cluster_name" {
  type        = string
  description = "The name of the ECS cluster to use for the shared ECS Cluster."
  default     = "perforce-cluster"
}

########################################
# Storage & Logging
########################################
variable "enable_shared_lb_access_logs" {
  type        = bool
  description = "Enables access logging for both the shared NLB and shared ALB. Defaults to false."
  default     = false
}

variable "shared_lb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for both the shared NLB and shared ALB access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
  # This should not be provided if access logging is disabled
  validation {
    condition     = var.enable_shared_lb_access_logs ? var.shared_lb_access_logs_bucket != null : true
    error_message = "If access logging is disabled, the variable 'shared_lb_access_logs_bucket' must not be provided."
  }
}

variable "shared_nlb_access_logs_prefix" {
  type        = string
  description = "Log prefix for shared NLB access logs."
  default     = "perforce-nlb-"
  # This should not be provided if access logging is disabled
  validation {
    condition     = var.enable_shared_lb_access_logs ? var.shared_nlb_access_logs_prefix != null : true
    error_message = "If access logging is disabled, the variable 'shared_nlb_access_logs_prefix' must not be provided."
  }
}
variable "shared_alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for shared ALB access logs."
  default     = "perforce-alb-"
  # This should not be provided if access logging is disabled
  validation {
    condition     = var.enable_shared_lb_access_logs ? var.shared_alb_access_logs_prefix != null : true
    error_message = "If access logging is disabled, the variable 'shared_alb_access_logs_prefix' must not be provided."
  }
}

variable "s3_enable_force_destroy" {
  type        = bool
  description = "Enables force destroy for the S3 bucket for both the shared NLB and shared ALB access log storage. Defaults to true."
  default     = true
  # This should not be provided if access logging is disabled
  validation {
    condition     = var.enable_shared_lb_access_logs ? var.s3_enable_force_destroy != null : true
    error_message = "If access logging is disabled, the variable 's3_enable_force_destroy' must not be provided."
  }
}


########################################
# Networking
########################################
variable "vpc_id" {
  type        = string
  description = "The VPC ID where the Perforce resources will be deployed."
}

variable "create_default_sgs" {
  type        = bool
  description = "Whether to create default security groups for the Perforce resources."
  default     = true
}

variable "existing_security_groups" {
  type        = list(string)
  description = "A list of existing security group IDs to attach to the shared network load balancer."
  default     = []
}

variable "shared_alb_subnets" {
  type        = list(string)
  description = "A list of subnets to attach to the shared application load balancer."
  default     = null
  # must be provided if create_shared_application_load_balancer is true
  validation {
    condition     = var.shared_alb_subnets != null ? length(var.shared_alb_subnets) > 0 : true
    error_message = "If create_shared_application_load_balancer is false, the variable 'shared_alb_subnets' must not be provided."
  }
}

variable "shared_nlb_subnets" {
  type        = list(string)
  description = "A list of subnets to attach to the shared network load balancer."
  default     = null
  # must be provided if create_shared_network_load_balancer is true
  validation {
    condition     = var.shared_nlb_subnets != null ? length(var.shared_nlb_subnets) > 0 : true
    error_message = "If create_shared_network_load_balancer is false, the variable 'shared_nlb_subnets' must not be provided."
  }
}

variable "create_shared_network_load_balancer" {
  type        = bool
  description = "Whether to create a shared Network Load Balancer for the Perforce resources."
  default     = true
}
variable "shared_network_load_balancer_name" {
  type        = string
  description = "The name of the shared Network Load Balancer for the Perforce resources."
  default     = "p4nlb"
}

variable "create_shared_application_load_balancer" {
  type        = bool
  description = "Whether to create a shared Application Load Balancer for the Perforce resources."
  default     = true
}

variable "shared_application_load_balancer_name" {
  type        = string
  description = "The name of the shared Application Load Balancer for the Perforce resources."
  default     = "p4alb"
}

variable "enable_shared_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the shared Application Load Balancer for the Perforce resources."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "The ARN of the ACM certificate to be used with the HTTPS listener for the NLB."
  default     = null
}

variable "create_route53_private_hosted_zone" {
  type        = bool
  description = "Whether to create a private Route53 Hosted Zone for the Perforce resources. This private hosted zone is used for internal communication between the P4 Server, P4 Auth Service, and P4 Code Review Service."
  default     = true
}

variable "route53_private_hosted_zone_name" {
  type        = string
  description = "The name of the private Route53 Hosted Zone for the Perforce resources."
  default     = null
  # Should only be provided if create_route53_private_hosted_zone is set to true
  validation {
    condition     = var.create_route53_private_hosted_zone ? var.route53_private_hosted_zone_name != null : true
    error_message = "If create_route53_private_hosted_zone is false, the variable 'route53_private_hosted_zone_name' must not be provided."
  }
}

########################################
# P4 Server
########################################
variable "p4_server_config" {
  type = object({
    # General
    name                        = optional(string, "p4-server")
    project_prefix              = optional(string, "cgd")
    environment                 = optional(string, "dev")
    auth_service_url            = optional(string, null)
    fully_qualified_domain_name = string

    # Compute
    lookup_existing_ami = optional(bool, true)
    ami_prefix          = optional(string, "p4_al2023")

    instance_type         = optional(string, "c6i.large")
    instance_architecture = optional(string, "x86_64")
    p4_server_type        = optional(string, null)

    unicode        = optional(bool, false)
    selinux        = optional(bool, false)
    case_sensitive = optional(bool, true)
    plaintext      = optional(bool, false)

    # Storage
    storage_type         = optional(string, "EBS")
    depot_volume_size    = optional(number, 128)
    metadata_volume_size = optional(number, 32)
    logs_volume_size     = optional(number, 32)

    # Networking & Security
    instance_subnet_id       = optional(string, null)
    instance_private_ip      = optional(string, null)
    create_default_sg        = optional(bool, true)
    existing_security_groups = optional(list(string), [])
    internal                 = optional(bool, false)

    super_user_password_secret_arn = optional(string, null)
    super_user_username_secret_arn = optional(string, null)

    create_default_role = optional(bool, true)
    custom_role         = optional(string, null)

    # FSxN
    fsxn_password                     = optional(string, null)
    fsxn_filesystem_security_group_id = optional(string, null)
    protocol                          = optional(string, null)
    fsxn_region                       = optional(string, null)
    fsxn_management_ip                = optional(string, null)
    fsxn_svm_name                     = optional(string, null)
    amazon_fsxn_svm_id                = optional(string, null)
    fsxn_aws_profile                  = optional(string, null)
  })
  description = <<EOT
    # - General -
    name: "The string including in the naming of resources related to P4 Server. Default is 'p4-server'"

    project_prefix: "The project prefix for this workload. This is appended to the beginning of most resource names."

    environment: "The current environment (e.g. dev, prod, etc.)"

    auth_service_url: "The URL for the P4Auth Service."

    fully_qualified_domain_name = "The FQDN for the P4 Server. This is used for the P4 Server's Perforce configuration."


    # - Compute -
    lookup_existing_ami : "Whether to lookup the existing Perforce P4 Server AMI."

    ami_prefix: "The AMI prefix to use for the AMI that will be created for P4 Server."

    instance_type: "The instance type for Perforce P4 Server. Defaults to c6g.large."

    instance_architecture: "The architecture of the P4 Server instance. Allowed values are 'arm64' or 'x86_64'."

    IMPORTANT: "Ensure the instance family of the instance type you select supports the instance_architecture you select. For example, 'c6in' instance family only works for 'x86_64' architecture, not 'arm64'. For a full list of this mapping, see the AWS Docs for EC2 Naming Conventions: https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html"

    p4_server_type: "The Perforce P4 Server server type. Valid values are 'p4d_commit' or 'p4d_replica'."

    unicode: "Whether to enable Unicode configuration for P4 Server the -xi flag for p4d. Set to true to enable Unicode support."

    selinux: "Whether to apply SELinux label updates for P4 Server. Don't enable this if SELinux is disabled on your target operating system."

    case_sensitive: "Whether or not the server should be case insensitive (Server will run '-C1' mode), or if the server will run with case sensitivity default of the underlying platform. False enables '-C1' mode. Default is set to true."

    plaintext: "Whether to enable plaintext authentication for P4 Server. This is not recommended for production environments unless you are using a load balancer for TLS termination. Default is set to false."


    # - Storage -
    storage_type: "The type of backing store. Valid values are either 'EBS' or 'FSxN'"

    depot_volume_size: "The size of the depot volume in GiB. Defaults to 128 GiB."

    metadata_volume_size: "The size of the metadata volume in GiB. Defaults to 32 GiB."

    logs_volume_size: "The size of the logs volume in GiB. Defaults to 32 GiB."


    # - Networking & Security -
    instance_subnet_id: "The subnet where the P4 Server instance will be deployed."

    instance_private_ip: "The private IP address to assign to the P4 Server."

    create_default_sg : "Whether to create a default security group for the P4 Server instance."

    existing_security_groups: "A list of existing security group IDs to attach to the P4 Server load balancer."

    internal: "Set this flag to true if you do not want the P4 Server instance to have a public IP."

    super_user_password_secret_arn: "If you would like to manage your own super user credentials through AWS Secrets Manager provide the ARN for the super user's username here. Otherwise, the default of 'perforce' will be used."

    super_user_username_secret_arn: "If you would like to manage your own super user credentials through AWS Secrets Manager provide the ARN for the super user's password here."

    create_default_role: "Optional creation of P4 Server default IAM Role with SSM managed instance core policy attached. Default is set to true."

    custom_role: "ARN of a custom IAM Role you wish to use with P4 Server."


  EOT

  default = null

  validation {
    condition     = length(var.p4_server_config.name) > 1 && length(var.p4_server_config.name) <= 50
    error_message = "The defined 'name' has too many characters (${length(var.p4_server_config.name)}). This can cause deployment failures for AWS resources with smaller character limits. Please reduce the character count and try again."
  }

  validation {
    condition     = var.p4_server_config.instance_architecture == "arm64" || var.p4_server_config.instance_architecture == "x86_64"
    error_message = "The p4_server_config.instance_architecture variable must be either 'arm64' or 'x86_64'."
  }

  validation {
    condition     = contains(["p4d_commit", "p4d_replica"], var.p4_server_config.p4_server_type)
    error_message = "${var.p4_server_config.p4_server_type} is not one of p4d_commit or p4d_replica."
  }

  validation {
    condition     = contains(["EBS", "FSxN"], var.p4_server_config.storage_type)
    error_message = "Not a valid storage type. Valid values are either 'EBS' or 'FSxN'."
  }

  validation {
    condition     = !var.create_route53_private_hosted_zone || var.route53_private_hosted_zone_name == var.p4_server_config.fully_qualified_domain_name
    error_message = "Route53 zone name and Perforce Server FQDN must match."
  }

}

########################################
# P4Auth
########################################
variable "p4_auth_config" {
  type = object({
    # - General -
    name                            = optional(string, "p4-auth")
    project_prefix                  = optional(string, "cgd")
    environment                     = optional(string, "dev")
    enable_web_based_administration = optional(bool, true)
    debug                           = optional(bool, false)
    fully_qualified_domain_name     = string

    # - Compute -
    container_name   = optional(string, "p4-auth-container")
    container_port   = optional(number, 3000)
    container_cpu    = optional(number, 1024)
    container_memory = optional(number, 4096)
    p4d_port         = optional(string, null)

    # - Storage & Logging -
    cloudwatch_log_retention_in_days = optional(number, 365)

    # - Networking & Security -
    service_subnets          = optional(list(string), null)
    create_default_sgs       = optional(bool, true)
    existing_security_groups = optional(list(string), [])
    internal                 = optional(bool, false)

    certificate_arn           = optional(string, null)
    create_default_role       = optional(bool, true)
    custom_role               = optional(string, null)
    admin_username_secret_arn = optional(string, null)
    admin_password_secret_arn = optional(string, null)

    # SCIM
    p4d_super_user_arn          = optional(string, null)
    p4d_super_user_password_arn = optional(string, null)
    scim_bearer_token_arn       = optional(string, null)
    extra_env                   = optional(map(string), null)
  })

  default = null

  description = <<EOT
    # General
    name: "The string including in the naming of resources related to P4Auth. Default is 'p4-auth'."

    project_prefix : "The project prefix for the P4Auth service. Default is 'cgd'."

    environment : "The environment where the P4Auth service will be deployed. Default is 'dev'."

    enable_web_based_administration: "Whether to de enable web based administration. Default is 'true'."

    debug : "Whether to enable debug mode for the P4Auth service. Default is 'false'."

    fully_qualified_domain_name : "The FQDN for the P4Auth Service. This is used for the P4Auth's Perforce configuration."


    # Compute
    cluster_name : "The name of the ECS cluster where the P4Auth service will be deployed. Cluster is not created if this variable is null."

    container_name : "The name of the P4Auth service container. Default is 'p4-auth-container'."

    container_port : "The port on which the P4Auth service will be listening. Default is '3000'."

    container_cpu : "The number of CPU units to reserve for the P4Auth service container. Default is '1024'."

    container_memory : "The number of CPU units to reserve for the P4Auth service container. Default is '4096'."

    pd4_port : "The full URL you will use to access the P4 Depot in clients such P4V and P4Admin. Note, this typically starts with 'ssl:' and ends with the default port of ':1666'."


    # Storage & Logging
    cloudwatch_log_retention_in_days : "The number of days to retain the P4Auth service logs in CloudWatch. Default is 365 days."


    # Networking
    create_defaults_sgs : "Whether to create default security groups for the P4Auth service."

    internal : "Set this flag to true if you do not want the P4Auth service to have a public IP."

    create_default_role : "Whether to create the P4Auth default IAM Role. Default is set to true."

    custom_role : "ARN of a custom IAM Role you wish to use with P4Auth."

    admin_username_secret_arn : "Optionally provide the ARN of an AWS Secret for the P4Auth Administrator username."

    admin_password_secret_arn : "Optionally provide the ARN of an AWS Secret for the P4Auth Administrator password."


    # - SCIM -
    p4d_super_user_arn : "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the super user username for p4d."

    p4d_super_user_password_arn : "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the super user password for p4d."

    scim_bearer_token_arn : "If you would like to use SCIM to provision users and groups, you need to set this variable to the ARN of an AWS Secrets Manager secret containing the bearer token."

    extra_env : "Extra configuration environment variables to set on the p4 auth svc container."


  EOT

}

########################################
# P4 Code Review
########################################
variable "p4_code_review_config" {
  type = object({
    # General
    name                        = optional(string, "p4-code-review")
    project_prefix              = optional(string, "cgd")
    environment                 = optional(string, "dev")
    debug                       = optional(bool, false)
    fully_qualified_domain_name = string

    # Compute
    container_name   = optional(string, "p4-code-review-container")
    container_port   = optional(number, 80)
    container_cpu    = optional(number, 1024)
    container_memory = optional(number, 4096)
    p4d_port         = optional(string, null)
    p4charset        = optional(string, null)
    existing_redis_connection = optional(object({
      host = string
      port = number
    }), null)

    # Storage & Logging
    cloudwatch_log_retention_in_days = optional(number, 365)

    # Networking & Security
    create_default_sgs       = optional(bool, true)
    existing_security_groups = optional(list(string), [])
    internal                 = optional(bool, false)
    service_subnets          = optional(list(string), null)

    create_default_role = optional(bool, true)
    custom_role         = optional(string, null)

    super_user_password_secret_arn          = optional(string, null)
    super_user_username_secret_arn          = optional(string, null)
    p4_code_review_user_password_secret_arn = optional(string, null)
    p4_code_review_user_username_secret_arn = optional(string, null)
    enable_sso                              = optional(string, true)
    config_php_source                       = optional(string, null)

    # Caching
    elasticache_node_count = optional(number, 1)
    elasticache_node_type  = optional(string, "cache.t4g.micro")
  })

  default = null

  description = <<EOT
    # General
    name: "The string including in the naming of resources related to P4 Code Review. Default is 'p4-code-review'."

    project_prefix : "The project prefix for the P4 Code Review service. Default is 'cgd'."

    environment : "The environment where the P4 Code Review service will be deployed. Default is 'dev'."

    debug : "Whether to enable debug mode for the P4 Code Review service. Default is 'false'."

    fully_qualified_domain_name : "The FQDN for the P4 Code Review Service. This is used for the P4 Code Review's Perforce configuration."


    # Compute
    container_name : "The name of the P4 Code Review service container. Default is 'p4-code-review-container'."

    container_port : "The port on which the P4 Code Review service will be listening. Default is '3000'."

    container_cpu : "The number of CPU units to reserve for the P4 Code Review service container. Default is '1024'."

    container_memory : "The number of CPU units to reserve for the P4 Code Review service container. Default is '4096'."

    pd4_port : "The full URL you will use to access the P4 Depot in clients such P4V and P4Admin. Note, this typically starts with 'ssl:' and ends with the default port of ':1666'."

    p4charset : "The P4CHARSET environment variable to set in the P4 Code Review container."

    existing_redis_connection : "The existing Redis connection for the P4 Code Review service."


    # Storage & Logging
    cloudwatch_log_retention_in_days : "The number of days to retain the P4 Code Review service logs in CloudWatch. Default is 365 days."


    # Networking & Security
    create_default_sgs : "Whether to create default security groups for the P4 Code Review service."

    internal : "Set this flag to true if you do not want the P4 Code Review service to have a public IP."

    create_default_role : "Whether to create the P4 Code Review default IAM Role. Default is set to true."

    custom_role : "ARN of a custom IAM Role you wish to use with P4 Code Review."

    super_user_password_secret_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review Administrator username."

    super_user_username_secret_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review Administrator password."

    p4d_p4_code_review_user_secret_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review user's username."

    p4d_p4_code_review_password_secret_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review user's password."

    p4d_p4_code_review_user_password_arn : "Optionally provide the ARN of an AWS Secret for the P4 Code Review user's password."

    enable_sso : "Whether to enable SSO for the P4 Code Review service. Default is set to false."

    config_php_source : "Used as the ValueFrom for P4CR's config.php. Contents should be base64 encoded, and will be combined with the generated config.php via array_replace_recursive."


    # Caching
    elasticache_node_count : "The number of Elasticache nodes to create for the P4 Code Review service. Default is '1'."

    elasticache_node_type : "The type of Elasticache node to create for the P4 Code Review service. Default is 'cache.t4g.micro'."

  EOT

}


variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources."
  default = {
    "IaC"            = "Terraform"
    "ModuleBy"       = "CGD-Toolkit"
    "RootModuleName" = "-"
    "ModuleName"     = "terraform-aws-perforce"
    "ModuleSource"   = "https://github.com/aws-games/cloud-game-development-toolkit/tree/main/modules/perforce"
  }
}
