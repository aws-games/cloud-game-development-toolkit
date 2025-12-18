####################################################
# General Configuration
####################################################

variable "name" {
  type        = string
  description = "The name applied to resources in the Unity Floating License Server module."
  default     = "unity-license-server"
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to resources created by this module."
  default = {
    "iac-management" = "CGD-Toolkit"
    "iac-module"     = "UnityFloatingLicenseServer"
    "iac-provider"   = "Terraform"
    "environment"    = "Dev"
  }
}

####################################################
# Networking
####################################################

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC in which the Unity Floating License Server will be deployed."
}

variable "vpc_subnet" {
  type        = string
  description = "The subnet where the EC2 instance running the Unity Floating License Server will be deployed."
}

variable "existing_eni_id" {
  type        = string
  description = "ID of an existing Elastic Network Interface (ENI) to use for the EC2 instance running the Unity Floating License Server, as its registration will be binded to it. If not provided, a new ENI will be created."
  default     = null
}

variable "add_eni_public_ip" {
  type        = bool
  description = "If true and \"existing_eni_id\" is not provided, an Elastic IP (EIP) will be created and associated with the newly created Elastic Network Interface (ENI) to be used with the Unity Floating License Server. If \"existing_eni_id\" is provided, this variable is ignored and no new EIP will be added to the provided ENI."
  default     = true
}

#############################################################
# Application Load Balancer
#############################################################

variable "create_alb" {
  type        = bool
  description = "Set this flag to true to create an Application Load Balancer for the Unity License Server dashboard."
  default     = true
}

variable "alb_is_internal" {
  type        = bool
  description = "Set this flag to determine whether the Application Load Balancer to create is internal (true) or external (false). Value is ignored if no ALB is created."
  default     = false
}

variable "alb_subnets" {
  type        = list(string)
  description = "The subnets in which the Application Load Balancer will be deployed."

  validation {
    condition     = !var.create_alb || length(var.alb_subnets) > 0
    error_message = "The alb_subnets variable must be set if create_alb is true."
  }
  default = []
}

variable "alb_certificate_arn" {
  type        = string
  description = "The ARN of the SSL certificate to use for the Application Load Balancer."

  validation {
    condition     = !var.create_alb || var.alb_certificate_arn != null
    error_message = "The alb_certificate_arn variable must be set if create_alb is true."
  }
  default = null
}

variable "enable_alb_deletion_protection" {
  type        = bool
  description = "Enables deletion protection for the Application Load Balancer. Defaults to true."
  default     = true
}

variable "enable_alb_access_logs" {
  type        = bool
  description = "Enables access logging for the Application Load Balancer used by Unity License Server. Defaults to true."
  default     = true
}

variable "alb_access_logs_prefix" {
  type        = string
  description = "Log prefix for Unity License Server Application Load Balancer access logs. If null the project prefix and module name are used."
  default     = null
}

variable "alb_access_logs_bucket" {
  type        = string
  description = "ID of the S3 bucket for Application Load Balancer access log storage. If access logging is enabled and this is null the module creates a bucket."
  default     = null
}

#############################################################
# Unity Floating License Server EC2 Instance Configuration
#############################################################

variable "unity_license_server_instance_ami_id" {
  type        = string
  description = "The Ubuntu-based AMI ID to use in the EC2 instance running the Unity Floating License Server. Defaults to the latest Ubuntu Server 24.04 LTS AMI."
  default     = null
}

variable "unity_license_server_instance_type" {
  type        = string
  description = "The instance type to use for the Unity Floating License Server. Defaults to t3.small."
  default     = "t3.small"
}

variable "unity_license_server_instance_ebs_size" {
  type        = string
  description = "The size of the EBS volume in GB."
  default     = "20"
}

variable "enable_instance_detailed_monitoring" {
  type        = bool
  description = "Enables detailed monitoring for the instance by increasing the frequency of metric collection from 5-minute intervals to 1-minute intervals in CloudWatch to provide more granular data. Note this will result in increased cost."
  default     = false
}

variable "enable_instance_termination_protection" {
  type        = bool
  description = "If true, enables EC2 instance termination protection from AWS APIs and console."
  default     = true
}

####################################################
# Unity Floating License Server Configuration
####################################################

variable "unity_license_server_file_path" {
  type        = string
  description = "Local path to the Linux version of the Unity Floating License Server zip file."
}

variable "unity_license_server_bucket_name" {
  type        = string
  description = "Name of the Unity Floating License Server-specific S3 bucket to create."
  default     = "unity-license-server-"
}

variable "unity_license_server_admin_password_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the Unity Floating License Server admin dashboard password. Password must be the only value and stored as text, not as key/value JSON. If not passed, one will be created randomly. Password must be between 8-12 characters."
  type        = string
  default     = null
}

variable "unity_license_server_name" {
  type        = string
  description = "Name of the Unity Floating License Server."
  default     = "UnityLicenseServer"
}

variable "unity_license_server_port" {
  type        = string
  description = "Port the Unity Floating License Server will listen on (between 1025 and 65535). Defaults to 8080."
  default     = "8080"
}
