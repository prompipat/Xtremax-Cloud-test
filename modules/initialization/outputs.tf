output "application_secret_arn" {
  description = "Application secret ARN only; the value is created inside Lambda at apply time."
  value       = aws_secretsmanager_secret.application.arn
}

output "ready" {
  description = "True after successful initialization; root compute dependency waits for this module."
  value       = try(jsondecode(aws_lambda_invocation.initialize.result).ready, false)
}
