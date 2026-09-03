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

##################################################
# Horde Agents
##################################################

variable "sync_agent_instance_type" {
  type        = string
  description = "EC2 instance type for the Sync Agent pool (network-optimized; performs p4 sync + snapshot into the FSxN source volume)."
  default     = "c6i.xlarge"
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

##################################################
# Horde Server
##################################################

# Pinned by digest to Horde/UE 5.5.0-32559309 for reproducibility so the server
# version cannot drift. The custom BuildGraph tasks and the Unreal engine source
# in Perforce must match this Horde/UE version — override only with a matching
# version. Pulling the default requires Epic Games GitHub org access.
variable "horde_server_image" {
  type        = string
  description = "Container image URI for the Horde server. Pinned by digest to Horde/UE 5.5.0-32559309 for reproducibility — the custom BuildGraph tasks and the Unreal engine source in Perforce must match this Horde/UE version. Override only with a matching version. Pulling the default requires Epic Games GitHub org access."
  default     = "ghcr.io/epicgames/horde-server@sha256:2a3a3009c05d1dcf4ecbed640d2eb4b5eb9ce974df056e011f476aba4cf5c12d"
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

# NON-SECRET. This is only the Perforce USERNAME that Horde logs in as (rendered
# into globals.json's perforceClusters "default" cluster as serviceAccount). It
# MUST match the "username" field inside the p4_credentials secret referenced by
# var.horde_p4_credentials_secret_arn. The PASSWORD is never rendered here — it
# is delivered separately via the secret (module server.json). Because this is a
# username only, rendering it via Terraform into globals.json / TF state is safe.
variable "horde_p4_service_account_username" {
  type        = string
  description = "NON-SECRET Perforce username Horde authenticates as (rendered into globals.json perforceClusters 'default' cluster as serviceAccount). MUST match the 'username' field in the p4_credentials secret (var.horde_p4_credentials_secret_arn). The password is delivered via the secret and is never rendered here."
  default     = "svc-horde"
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
