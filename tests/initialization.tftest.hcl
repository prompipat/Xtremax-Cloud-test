mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { region = "ap-southeast-2" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/test-initializer" }
  }
  mock_resource "aws_lambda_invocation" {
    defaults = { result = "{\"ready\":true}" }
  }
}

run "separate_database_initializer" {
  command = apply
  module {
    source = "./modules/initialization"
  }
  variables {
    name              = "initializer-test"
    subnet_ids        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_id = "sg-0123456789abcdef0"
    db_address        = "database.example.internal"
    master_secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:master-test"
    package_file      = "./artifacts/db-initializer.zip"
  }

  assert {
    condition     = aws_lambda_invocation.initialize.lifecycle_scope == "CREATE_ONLY" && output.ready
    error_message = "Initialization must report readiness and never invoke the function during destroy."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.initializer.policy).Statement : statement
      if statement.Effect == "Allow" && statement.Action == "secretsmanager:GetSecretValue" && statement.Resource == var.master_secret_arn
    ]) == 1
    error_message = "Master secret read must be explicitly scoped to the RDS master ARN."
  }

  assert {
    condition     = length(one(aws_lambda_function.initializer.vpc_config).subnet_ids) == 2 && aws_lambda_function.initializer.timeout == 180
    error_message = "The initializer must use the private network and an explicit timeout."
  }

  assert {
    condition = (
      !contains(keys(one(aws_lambda_function.initializer.environment).variables), "DB_PASSWORD") &&
      one(aws_lambda_function.initializer.environment).variables.MASTER_SECRET_ARN == var.master_secret_arn
    )
    error_message = "Lambda environment must pass secret ARNs, never database passwords."
  }
}
