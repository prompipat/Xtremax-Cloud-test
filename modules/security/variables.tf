variable "name" {
  description = "Resource name prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC containing all workload security groups."
  type        = string
}
