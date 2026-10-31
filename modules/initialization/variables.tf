variable "name" {
  type        = string
  description = "Prefix for initializer resources."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private application subnets with NAT access to Secrets Manager."
}

variable "security_group_id" {
  type        = string
  description = "Application SG, providing access to the private DB and HTTPS APIs."
}

variable "db_address" {
  type        = string
  description = "RDS endpoint used with TLS hostname verification."
}

variable "master_secret_arn" {
  type        = string
  description = "RDS-managed master secret; never granted to the EC2 runtime role."
}

variable "package_file" {
  type        = string
  description = "ZIP built with scripts/prepare-artifacts.py before Terraform plan."
}
