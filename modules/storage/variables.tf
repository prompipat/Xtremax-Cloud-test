variable "name" {
  description = "EFS resource name prefix."
  type        = string
}

variable "subnet_ids" {
  description = "Application subnet IDs keyed by availability zone."
  type        = map(string)

  validation {
    condition     = length(var.subnet_ids) == 2
    error_message = "Provide an application subnet in each of the two AZs."
  }
}

variable "security_group_id" {
  description = "EFS security group accepting NFS only from application instances."
  type        = string
}
