variable "name" {
  description = "Name prefix for network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 /16 network, divided into six /24 subnets."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/16$", var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 /16 CIDR."
  }
}

variable "availability_zones" {
  description = "Two distinct standard availability zones in the provider region."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "Supply exactly two distinct availability zones."
  }
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for a lab; false gives each AZ its own gateway."
  type        = bool
  default     = false
}
