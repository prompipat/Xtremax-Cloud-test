variable "name" {
  description = "ALB and target-group name prefix."
  type        = string
}

variable "vpc_id" {
  description = "Application VPC ID."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs in two AZs."
  type        = list(string)
}

variable "security_group_id" {
  description = "ALB SG allowing HTTPS from the CloudFront managed prefix list."
  type        = string
}

variable "certificate_arn" {
  description = "Validated origin ACM certificate in the ALB region."
  type        = string
}

variable "origin_header_value" {
  description = "Private value shared only between this listener and the CloudFront origin."
  type        = string
  sensitive   = true
}
