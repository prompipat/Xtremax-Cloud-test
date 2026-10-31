variable "name" {
  description = "Resource name prefix."
  type        = string
}

variable "ami_id" {
  description = "Pinned, Amazon-owned AL2023 x86_64 image ID for this region."
  type        = string
}

variable "instance_type" {
  description = "x86_64 EC2 type; default is burstable with explicit unlimited credits."
  type        = string
  default     = "t3.small"
  validation {
    condition     = startswith(var.instance_type, "t3.")
    error_message = "This launch template explicitly configures T3 credits; select a t3 instance type."
  }
}

variable "subnet_ids" {
  description = "Private application subnet IDs."
  type        = list(string)
}

variable "security_group_id" {
  description = "Application security group."
  type        = string
}

variable "application_secret_arn" {
  description = "Initialized application secret ARN; no master secret permission is granted."
  type        = string
}

variable "db_address" {
  description = "Private RDS DNS endpoint, matching its TLS certificate."
  type        = string
}

variable "efs" {
  description = "Filesystem and access-point metadata."
  type = object({
    id               = string
    arn              = string
    access_point_id  = string
    access_point_arn = string
  })
}

variable "downloads" {
  description = "Verified release and RDS CA URLs and SHA256 checksums."
  type = object({
    wordpress = object({ version = string, url = string, sha256 = string })
    rds_ca    = object({ url = string, sha256 = string })
  })
}

variable "site_url" {
  description = "Canonical HTTPS website URL; replace any example placeholder before deployment."
  type        = string
  validation {
    condition     = can(regex("^https://[a-zA-Z0-9.-]+$", var.site_url))
    error_message = "Use an HTTPS site origin without a path or trailing slash."
  }
}

variable "admin_email" {
  description = "WordPress administrator email; initial admin credentials live in the application secret."
  type        = string
}

variable "desired_capacity" {
  description = "Initial size; dynamic scaling subsequently owns desired capacity."
  type        = number
  default     = 2
  validation {
    condition     = var.desired_capacity >= 1 && var.desired_capacity <= 4 && floor(var.desired_capacity) == var.desired_capacity
    error_message = "desired_capacity must be an integer from 1 to 4."
  }
}

variable "target_group_arns" {
  description = "ALB target groups; when supplied the ASG uses ELB health checks."
  type        = set(string)
  default     = []
}
