resource "aws_efs_file_system" "this" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"
  tags             = { Name = "${var.name}-content" }
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "this" {
  for_each = var.subnet_ids

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [var.security_group_id]
}

resource "aws_efs_access_point" "wordpress" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 48
    gid = 48
  }

  root_directory {
    path = "/wordpress"

    creation_info {
      owner_uid   = 48
      owner_gid   = 48
      permissions = "0755"
    }
  }

  tags = { Name = "${var.name}-wordpress" }
}

# Explicit guardrails; the future EC2 role must separately grant ClientMount
# and ClientWrite on this filesystem. No anonymous/public Allow is added.
resource "aws_efs_file_system_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite", "elasticfilesystem:ClientRootAccess"]
        Resource  = aws_efs_file_system.this.arn
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyOtherAccessPoints"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite", "elasticfilesystem:ClientRootAccess"]
        Resource  = aws_efs_file_system.this.arn
        Condition = { StringNotEquals = { "elasticfilesystem:AccessPointArn" = aws_efs_access_point.wordpress.arn } }
      },
      {
        Sid       = "DenyRootAccess"
        Effect    = "Deny"
        Principal = "*"
        Action    = "elasticfilesystem:ClientRootAccess"
        Resource  = aws_efs_file_system.this.arn
      }
    ]
  })
}
