data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  function_name = "${var.name}-db-init"
  function_arn  = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${local.function_name}"
  eni_actions = [
    "ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSubnets",
    "ec2:DeleteNetworkInterface", "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"
  ]
}

resource "aws_secretsmanager_secret" "application" {
  name_prefix             = "${var.name}-application-"
  description             = "Schema-scoped DB credentials, WordPress salts and initial site admin credentials"
  recovery_window_in_days = 7
}

resource "aws_iam_role" "initializer" {
  name_prefix = "${var.name}-db-init-"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_cloudwatch_log_group" "initializer" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 30
}

resource "aws_iam_role_policy" "initializer" {
  role = aws_iam_role.initializer.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = var.master_secret_arn },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue"], Resource = aws_secretsmanager_secret.application.arn },
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.initializer.arn}:*" },
      # AWS documents Resource * for these Hyperplane ENI operations.
      { Effect = "Allow", Action = local.eni_actions, Resource = "*" },
      # Prevent application code from using the ENI permissions; Lambda's service
      # operations do not carry lambda:SourceFunctionArn and remain permitted.
      { Effect = "Deny", Action = local.eni_actions, Resource = "*", Condition = { ArnEquals = { "lambda:SourceFunctionArn" = local.function_arn } } }
    ]
  })
}

resource "aws_lambda_function" "initializer" {
  function_name    = local.function_name
  role             = aws_iam_role.initializer.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = var.package_file
  source_code_hash = filebase64sha256(var.package_file)
  timeout          = 180
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      DB_ADDRESS             = var.db_address
      MASTER_SECRET_ARN      = var.master_secret_arn
      APPLICATION_SECRET_ARN = aws_secretsmanager_secret.application.arn
    }
  }

  depends_on = [aws_iam_role_policy.initializer]
}

resource "aws_lambda_invocation" "initialize" {
  function_name   = aws_lambda_function.initializer.function_name
  lifecycle_scope = "CREATE_ONLY"
  input           = jsonencode({ operation = "initialize" })
  triggers = {
    code_hash  = aws_lambda_function.initializer.source_code_hash
    db_address = var.db_address
    secret_arn = aws_secretsmanager_secret.application.arn
  }

  lifecycle {
    postcondition {
      condition     = try(jsondecode(self.result).ready, false)
      error_message = "Database initialization did not report ready; do not launch the application fleet."
    }
  }
}
