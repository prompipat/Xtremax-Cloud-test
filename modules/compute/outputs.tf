output "autoscaling_group_name" {
  description = "ASG name for operations and runtime tests."
  value       = aws_autoscaling_group.wordpress.name
}

output "instance_role_arn" {
  description = "Restricted application instance role."
  value       = aws_iam_role.wordpress.arn
}

output "launch_template_id" {
  description = "Versioned WordPress launch template."
  value       = aws_launch_template.wordpress.id
}
