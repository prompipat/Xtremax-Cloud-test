variable "aws_region" {
  description = "AWS region for the application infrastructure."
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used to authenticate Terraform."
  type        = string
  default     = "xtremax"
}

variable "aws_account_id" {
  description = "Expected AWS account ID. The provider refuses to use another account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
}

variable "vpc_cidr" {
  description = "IPv4 /16 network for the project."
  type        = string
  default     = "10.20.0.0/16"
}

variable "single_nat_gateway" {
  description = "Set true only for a lower-cost lab with one shared NAT gateway."
  type        = bool
  default     = false
}

variable "db_engine_version" {
  description = "Pinned MySQL 8.4 patch version, verified available in the target region."
  type        = string
  default     = "8.4.11"
}

variable "db_instance_class" {
  description = "RDS instance size."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Use RDS Multi-AZ; false is a lower-cost lab option."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Prevent deletion of the database until explicitly disabled."
  type        = bool
  default     = true
}

variable "db_final_snapshot_identifier" {
  description = "Final snapshot name; choose a new unique value for each deployment lifecycle."
  type        = string
  default     = "xtremax-wordpress-final-001"
}

variable "wordpress_ami_id" {
  description = "Amazon-owned AL2023 x86_64 AMI pinned for ap-southeast-2; reselect when changing region."
  type        = string
  default     = "ami-062900c135ab91582"
}

variable "wordpress_instance_type" {
  description = "T3 x86_64 instance size. Unlimited credits can incur surplus charges under sustained load."
  type        = string
  default     = "t3.small"
}

variable "wordpress_desired_capacity" {
  description = "Initial ASG capacity."
  type        = number
  default     = 2
}

variable "site_url" {
  description = "Canonical HTTPS origin. The default is a PLAN-ONLY placeholder; replace before deployment."
  type        = string
  default     = "https://school.example.com"
  validation {
    condition     = can(regex("^https://[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.site_url))
    error_message = "Supply a public HTTPS DNS origin without a path, port or trailing slash."
  }
}

variable "site_admin_email" {
  description = "WordPress administrator email; replace the plan-only example before deployment."
  type        = string
  default     = "admin@example.com"
}

variable "origin_domain_name" {
  description = "Owned DNS hostname for origin HTTPS. The default is a PLAN-ONLY placeholder."
  type        = string
  default     = "origin.example.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.origin_domain_name))
    error_message = "Supply an origin DNS name without a scheme, wildcard or path."
  }
  validation {
    condition     = lower(var.origin_domain_name) != lower(trimprefix(var.site_url, "https://"))
    error_message = "The ALB origin name must differ from the CloudFront site alias to avoid a DNS loop."
  }
}

variable "hosted_zone_id" {
  description = "Existing public Route 53 zone for both DNS names, or null for manual external DNS."
  type        = string
  default     = null
}
