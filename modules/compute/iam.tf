data "aws_partition" "current" {}

resource "aws_iam_role" "wordpress" {
  name_prefix = "${var.name}-ec2-"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "wordpress" {
  role = aws_iam_role.wordpress.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "ReadApplicationSecret", Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.application_secret_arn },
      {
        Sid      = "MountWordPressContent"
        Effect   = "Allow"
        Action   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
        Resource = var.efs.arn
        Condition = {
          StringEquals = { "elasticfilesystem:AccessPointArn" = var.efs.access_point_arn }
          Bool         = { "aws:SecureTransport" = "true", "elasticfilesystem:AccessedViaMountTarget" = "true" }
        }
      },
      # These agent registration/channel operations have no usable per-instance
      # resource scope. No parameter-store read or secret write access is granted.
      { Sid = "RegisterWithSSM", Effect = "Allow", Action = "ssm:UpdateInstanceInformation", Resource = "*" },
      {
        Sid      = "SessionManagerChannels"
        Effect   = "Allow"
        Action   = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "wordpress" {
  name_prefix = "${var.name}-"
  role        = aws_iam_role.wordpress.name
}
