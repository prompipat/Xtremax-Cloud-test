resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids
  tags       = { Name = var.name }
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-"
  family      = "mysql8.4"
  description = "MySQL TLS enforcement and slow-query logging"

  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "database" {
  for_each = toset(["error", "slowquery"])

  name              = "/aws/rds/instance/${var.name}/${each.key}"
  retention_in_days = 30
}

resource "aws_db_instance" "this" {
  identifier                      = var.name
  engine                          = "mysql"
  engine_version                  = var.engine_version
  instance_class                  = var.instance_class
  db_name                         = "wordpress"
  username                        = "wpadmin"
  manage_master_user_password     = true
  port                            = 3306
  allocated_storage               = 20
  max_allocated_storage           = 100
  storage_type                    = "gp3"
  storage_encrypted               = true
  multi_az                        = var.multi_az
  publicly_accessible             = false
  db_subnet_group_name            = aws_db_subnet_group.this.name
  parameter_group_name            = aws_db_parameter_group.this.name
  vpc_security_group_ids          = [var.security_group_id]
  backup_retention_period         = 7
  backup_window                   = "15:00-16:00"
  maintenance_window              = "sun:17:00-sun:18:00"
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = false
  final_snapshot_identifier       = var.final_snapshot_identifier
  delete_automated_backups        = false
  auto_minor_version_upgrade      = true
  allow_major_version_upgrade     = false
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  tags                            = { Name = var.name }

  depends_on = [aws_cloudwatch_log_group.database]
}
