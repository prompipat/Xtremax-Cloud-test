variable "name" {
  description = "CloudFront policy name prefix."
  type        = string
}

variable "site_domain_name" {
  description = "Custom site alias covered by the us-east-1 viewer certificate."
  type        = string
}

variable "origin_domain_name" {
  description = "Origin DNS name pointing to the ALB and covered by its regional certificate."
  type        = string
}

variable "viewer_certificate_arn" {
  description = "Validated viewer ACM certificate in us-east-1."
  type        = string
}

variable "origin_header_value" {
  description = "Private value matched by the ALB listener."
  type        = string
  sensitive   = true
}
