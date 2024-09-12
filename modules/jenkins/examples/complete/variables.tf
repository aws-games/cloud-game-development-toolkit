variable "fully_qualified_domain_name" {
  type        = string
  description = "The fully qualified domain name (FQDN) to be used for jenkins"
}

variable "jenkins_agent_secret_arns" {
  type        = list(string)
  description = "A list of secretmanager ARNs (wildcards allowed) that contain any secrets which need to be accessed by the Jenkins service."
  default     = null
}
