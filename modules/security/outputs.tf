output "security_group_ids" {
  description = "Dedicated security group IDs keyed by workload tier."
  value       = { for tier, group in aws_security_group.tier : tier => group.id }
}
