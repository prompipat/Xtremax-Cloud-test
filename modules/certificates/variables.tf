variable "name" {
  type        = string
  description = "Certificate tag prefix."
}

variable "site_domain_name" {
  type        = string
  description = "Owned public site DNS name, without a scheme or path."
}

variable "origin_domain_name" {
  type        = string
  description = "Owned origin DNS name matching the ALB certificate."
}

variable "hosted_zone_id" {
  type        = string
  description = "Public Route 53 zone for both names, or null for external DNS validation."
  default     = null
}
