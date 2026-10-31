output "target_group_arn" {
  description = "Instance target group attached to the ASG."
  value       = aws_lb_target_group.wordpress.arn
}

output "dns_name" {
  description = "ALB alias target; do not use as CloudFront HTTPS origin hostname."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "ALB canonical hosted-zone ID for Route 53 alias records."
  value       = aws_lb.this.zone_id
}
