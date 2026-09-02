##################################################
# General
##################################################

variable "project_prefix" {
  type        = string
  description = "The prefix applied to all resource names in this sample."
  default     = "cgd"
}

variable "region" {
  type        = string
  description = "The AWS region into which this sample is deployed."
  default     = "us-east-1"
}

##################################################
# Networking
##################################################

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC created by this sample."
  default     = "10.0.0.0/16"
}

variable "route53_private_zone_name" {
  type        = string
  description = "The name of the Route53 private hosted zone used for internal service discovery (e.g., 'studio.internal')."

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.route53_private_zone_name))
    error_message = "Must be a valid domain name (e.g., studio.internal)"
  }
}

variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The fully qualified domain name of your existing Route53 public hosted zone. Used for the ACM certificate and the Horde HTTPS endpoint (e.g., 'example.com')."

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.route53_public_hosted_zone_name))
    error_message = "Must be a valid domain name (e.g., example.com)"
  }
}

variable "certificate_domain" {
  type        = string
  description = "The domain name for the ACM certificate used by the Horde HTTPS endpoint (e.g., 'horde.example.com')."

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.certificate_domain))
    error_message = "Must be a valid domain name (e.g., horde.example.com)"
  }
}

##################################################
# Perforce
##################################################

variable "perforce_stream" {
  type        = string
  description = "The Perforce stream to sync into the FSxN source volume (e.g., '//YourGame/main')."

  validation {
    condition     = can(regex("^//", var.perforce_stream))
    error_message = "The perforce_stream must be a Perforce stream path beginning with '//' (e.g., //YourGame/main)."
  }
}

variable "perforce_server_name" {
  type        = string
  description = "The name/subdomain used for the Perforce server."
  default     = "perforce"
}

variable "existing_perforce_server_endpoint" {
  type        = string
  description = "Endpoint of an existing Perforce server (e.g., 'ssl:perforce.example.com:1666'). If set, the sample skips deploying the bundled Perforce module and wires agents to this endpoint instead."
  default     = null
}

##################################################
# FSx for NetApp ONTAP
##################################################

variable "fsxn_storage_capacity_gb" {
  type        = number
  description = "Storage capacity of the FSx for ONTAP file system, in GiB."
  default     = 1024
}

variable "fsxn_throughput_capacity" {
  type        = number
  description = "Throughput capacity of the FSx for ONTAP file system, in MB/s. Valid SINGLE_AZ_1 values are 128, 256, 512, 1024, 2048, 4096."
  default     = 128
}

variable "fsxn_san_volume_size_gb" {
  type        = number
  description = "Size of the SAN container volume holding the workspace LUN, in GiB. Must exceed fsxn_lun_size with headroom for snapshot deltas: each snapshot the hydrator keeps costs the blocks changed since the previous one, so sizing this equal to the LUN makes snapshot creation start failing."
  default     = 600
}

variable "fsxn_lun_size" {
  type        = string
  description = "Size of the thin-provisioned workspace LUN in ONTAP notation (e.g. \"250g\"). Should comfortably exceed the synced stream size; it is thin, so unused capacity is not consumed."
  default     = "250g"
}

##################################################
# Horde Agents
##################################################

variable "sync_agent_instance_type" {
  type        = string
  description = "EC2 instance type for the Sync Agent (hydrator) pool. NOTE: on the SAN path this pool is WINDOWS, because the source LUN carries NTFS and its single writer must therefore be Windows."
  default     = "c6i.2xlarge"
}

variable "build_agent_instance_type" {
  type        = string
  description = "EC2 instance type for the Build Agent pool (compute-optimized; clones the FSxN snapshot and compiles)."
  default     = "c6a.8xlarge"
}

variable "build_agent_max_count" {
  type        = number
  description = "Maximum number of Build Agent instances in the Auto Scaling Group."
  default     = 5
}

# Horde build/sync agent AMI. Built by the Packer template at
# assets/packer/build-agents/windows-horde. Leave build_agent_ami_id null to
# have the sample look up the most recent AMI matching
# build_agent_ami_name_prefix in this account (keeps the sample generic - no
# hardcoded ami-xxxx). Set build_agent_ami_id to pin a specific image.
variable "build_agent_ami_id" {
  type        = string
  description = "Explicit AMI ID for the Horde Windows build/sync agents. When null, the sample looks up the newest self-owned AMI matching build_agent_ami_name_prefix."
  default     = null
}

variable "build_agent_ami_name_prefix" {
  type        = string
  description = "Name filter (with wildcard) used to look up the Packer-built Horde agent AMI when build_agent_ami_id is null. Must match the Packer template's ami_prefix."
  default     = "windows-horde-build-agent-*"
}

##################################################
# Horde Server
##################################################

variable "horde_server_image" {
  type        = string
  description = "Container image URI for the Horde server. The default requires Epic Games organization access to GitHub Container Registry."
  default     = "ghcr.io/epicgames/horde-server:latest-bundled"
}

variable "github_credentials_secret_arn" {
  type        = string
  description = "ARN of a Secrets Manager secret holding GitHub credentials used to pull Epic's private Horde container image. Set to null if the image does not require authentication."
  default     = null
}

variable "horde_p4_credentials_secret_arn" {
  type        = string
  description = "ARN of a pre-created Secrets Manager secret holding the Horde P4 credentials as JSON {\"username\":\"...\",\"password\":\"...\"}. Passing a pre-created secret keeps its ARN known at plan time. Required when deploying the bundled Perforce server (existing_perforce_server_endpoint = null); may be null only if wiring an existing Perforce with its own credentials handling."
  default     = null
}

variable "enable_new_agents_by_default" {
  type        = bool
  description = "Whether newly registered Horde agents are enabled automatically."
  default     = true
}

##################################################
# External Access
##################################################

variable "additional_allowed_cidrs" {
  type        = list(string)
  description = "Additional operator CIDR blocks (e.g. individual /32s) allowed to reach the Horde external ALB (HTTPS 443 + HTTP 80 redirect), in addition to the auto-detected deployer IP. Each entry MUST be a specific CIDR; never 0.0.0.0/0."
  default     = []
  validation {
    condition     = alltrue([for c in var.additional_allowed_cidrs : c != "0.0.0.0/0" && c != "::/0"])
    error_message = "additional_allowed_cidrs must not contain 0.0.0.0/0 or ::/0 - external access must be scoped to specific CIDRs."
  }
}
