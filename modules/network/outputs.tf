output "vpc_id" {
  description = "VPC identifier used by workload security groups."
  value       = aws_vpc.this.id
}

output "subnets" {
  description = "Subnet IDs, CIDRs and zones grouped by workload tier."
  value = {
    for tier in ["public", "application", "database"] : tier => {
      for key, config in local.subnets : config.zone => {
        id   = aws_subnet.this[key].id
        cidr = config.cidr
      } if config.tier == tier
    }
  }
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by their availability zone."
  value       = { for zone, gateway in aws_nat_gateway.this : zone => gateway.id }
}
