variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The fully qualified domain name of your existing Route53 Hosted Zone (e.g., 'example.com')."

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.route53_public_hosted_zone_name))
    error_message = "Must be a valid domain name (e.g., example.com)"
  }
}

variable "unity_license_server_file_path" {
  type        = string
  description = "Local path to the Linux version of the Unity Floating License Server zip file. Download from Unity ID portal at https://id.unity.com/. Set to null to skip Unity License Server deployment."
  default     = null
}

variable "unity_teamcity_agent_image" {
  type        = string
  description = "Container image URI for Unity TeamCity build agents. Must include Unity Hub and Unity Editor. Build your own using the Dockerfile in docker/teamcity-unity-build-agent/, or set to null to skip Unity agent deployment."
  default     = null
}
