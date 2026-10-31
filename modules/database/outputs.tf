output "connection" {
  description = "Database metadata; contains no password or secret value."
  value = {
    address           = aws_db_instance.this.address
    port              = aws_db_instance.this.port
    database_name     = aws_db_instance.this.db_name
    master_secret_arn = aws_db_instance.this.master_user_secret[0].secret_arn
  }
}
