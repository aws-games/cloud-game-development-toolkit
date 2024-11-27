variable "root_domain_name" {
  type        = string
  description = "The root domain name you would like to use for DNS."
}
variable "helix_core_server_type" {
  type    = string
  default = "commit"
}