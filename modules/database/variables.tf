variable "name" {
  description = "RDS instance and resource name prefix."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated subnet IDs in two availability zones."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) == 2
    error_message = "RDS requires two subnet IDs in distinct AZs."
  }
}

variable "security_group_id" {
  description = "Dedicated database security group permitting application MySQL only."
  type        = string
}

variable "engine_version" {
  description = "Pinned RDS MySQL 8.4 version verified in the deployment region."
  type        = string
  default     = "8.4.11"

  validation {
    condition     = startswith(var.engine_version, "8.4.")
    error_message = "This module's parameter group supports MySQL 8.4.x."
  }
}

variable "instance_class" {
  description = "RDS DB instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "multi_az" {
  description = "Provision a standby in another AZ."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental deletion; disable explicitly before intentional teardown."
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Unique identifier for the final snapshot when the DB is deleted."
  type        = string
}
