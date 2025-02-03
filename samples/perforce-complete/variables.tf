variable "root_domain_name" {
  type        = string
  description = "The root domain name you would like to use for DNS."
  default     = "novekm.people.aws.dev"
}


variable "sender_email_address" {
  type        = string
  description = "The email address you would like Amazon SES to send emails from."
  default     = "kevonmayers31@gmail.com"
}


variable "receiver_email_address" {
  type        = string
  description = "The email address you would like Amazon SES to send emails to. While SES is in the 'sandbox' state, you can only send emails to addresses that are verified in SES."
  default     = "novekm@amazon.com"
}

# Conditional Variables

variable "enable_dkim_auto_verification" {
  type        = bool
  description = "Whether or not to automatically verify DKIM for the domain identity. This variable may only be used if you are using Amazon Route 53 as your DNS provider."
  default     = true
}

variable "export_dkim_tokens" {
  type        = bool
  description = "Whether or not to export the DKIM tokens for the domain identity. These tokens must used when adding the required CNAME records in your DNS provider settings. These records are used for domain validation with Amazon SES."
  default     = false
}
