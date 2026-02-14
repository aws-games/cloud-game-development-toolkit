variable "name" {
  type        = string
  description = "The name applied to resources in the Unity Floating License Server module."
  default     = "unity-license-server"
}

variable "root_domain_name" {
  type        = string
  description = "The root domain name for the Hosted Zone where Unity Floating License Server record should be created."
}

variable "unity_license_server_file_path" {
  type        = string
  description = "Local path to the Linux version of the Unity Floating License Server zip file."
}
