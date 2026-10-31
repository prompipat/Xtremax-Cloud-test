output "file_system" {
  description = "Filesystem and access-point identifiers for the future EC2 role and mount."
  value = {
    id               = aws_efs_file_system.this.id
    arn              = aws_efs_file_system.this.arn
    access_point_id  = aws_efs_access_point.wordpress.id
    access_point_arn = aws_efs_access_point.wordpress.arn
    dns_name         = aws_efs_file_system.this.dns_name
  }
}

output "mount_target_ids" {
  description = "Mount target IDs by AZ; compute must wait for mount targets before bootstrapping."
  value       = { for zone, target in aws_efs_mount_target.this : zone => target.id }
}
