variable "route53_public_hosted_zone_name" {
  type        = string
  description = "The fully qualified domain name of your existing Route53 Hosted Zone (e.g., 'example.com')."
}

variable "unity_license_server_file_path" {
  type        = string
  description = "Local path to the Linux version of the Unity Floating License Server zip file. Download from Unity ID portal at https://id.unity.com/. Set to null to skip Unity License Server deployment."
  default     = null
}
