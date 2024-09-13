variable "fully_qualified_domain_name" {
  type        = string
  description = "A fully qualified domain name (FQDN) to be used for jenkins. A record will be created on the hosted zone with the following patterns 'jenkins.<your_fqdn>'"
}

variable "jenkins_agent_secret_arns" {
  type        = list(string)
  description = "A list of secretmanager ARNs (wildcards allowed) that contain any secrets which need to be accessed by the Jenkins service."
  default     = []
}
