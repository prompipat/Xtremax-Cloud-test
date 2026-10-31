# All apply commands in this test file use a mock provider, never real AWS.
mock_provider "aws" {
  mock_data "aws_ec2_managed_prefix_list" {
    defaults = {
      id = "pl-0123456789abcdef0"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:test-only"
        secret_status = "active"
        kms_key_id    = "test-key"
      }]
    }
  }
}

run "security_boundaries" {
  command = apply

  module {
    source = "./modules/security"
  }

  variables {
    name   = "security-test"
    vpc_id = "vpc-0123456789abcdef0"
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.cloudfront_alb.prefix_list_id == data.aws_ec2_managed_prefix_list.cloudfront.id &&
      aws_vpc_security_group_ingress_rule.cloudfront_alb.from_port == 443 &&
      aws_vpc_security_group_ingress_rule.cloudfront_alb.to_port == 443
    )
    error_message = "ALB ingress must use the CloudFront prefix list on HTTPS."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.internal["application_db"].security_group_id == aws_security_group.tier["database"].id &&
      aws_vpc_security_group_ingress_rule.internal["application_db"].referenced_security_group_id == aws_security_group.tier["application"].id &&
      aws_vpc_security_group_ingress_rule.internal["application_db"].from_port == 3306 &&
      aws_vpc_security_group_ingress_rule.internal["application_db"].to_port == 3306
    )
    error_message = "MySQL must accept only the application security group."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.internal["application_efs"].security_group_id == aws_security_group.tier["efs"].id &&
      aws_vpc_security_group_ingress_rule.internal["application_efs"].referenced_security_group_id == aws_security_group.tier["application"].id &&
      aws_vpc_security_group_ingress_rule.internal["application_efs"].from_port == 2049
    )
    error_message = "NFS must accept only the application security group."
  }

  assert {
    condition = alltrue([
      for rule in aws_vpc_security_group_egress_rule.internal :
      rule.security_group_id != aws_security_group.tier["database"].id && rule.security_group_id != aws_security_group.tier["efs"].id
    ])
    error_message = "Database and EFS must not initiate outbound connections."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.application_https.from_port == 443 &&
      aws_vpc_security_group_egress_rule.application_https.to_port == 443
    )
    error_message = "Application internet egress must be limited to HTTPS."
  }
}

run "private_encrypted_mysql" {
  command = apply

  module {
    source = "./modules/database"
  }

  variables {
    name                      = "database-test"
    subnet_ids                = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_id         = "sg-0123456789abcdef0"
    final_snapshot_identifier = "database-test-final-001"
  }

  assert {
    condition = (
      !aws_db_instance.this.publicly_accessible && aws_db_instance.this.storage_encrypted &&
      aws_db_instance.this.multi_az && aws_db_instance.this.manage_master_user_password
    )
    error_message = "RDS must be private, encrypted, Multi-AZ, and use an RDS-managed password."
  }

  assert {
    condition = (
      aws_db_instance.this.backup_retention_period == 7 &&
      aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot &&
      !aws_db_instance.this.delete_automated_backups
    )
    error_message = "RDS backup and deletion controls must remain enabled by default."
  }

  assert {
    condition     = length([for parameter in aws_db_parameter_group.this.parameter : parameter if parameter.name == "require_secure_transport" && parameter.value == "ON"]) == 1
    error_message = "MySQL must reject unencrypted database connections."
  }

  assert {
    condition     = output.connection.master_secret_arn == "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:test-only"
    error_message = "The application integration must receive the managed secret ARN."
  }
}

run "single_az_lab_database" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    name                      = "database-test"
    subnet_ids                = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    security_group_id         = "sg-0123456789abcdef0"
    final_snapshot_identifier = "database-test-final-002"
    multi_az                  = false
  }

  assert {
    condition     = !aws_db_instance.this.multi_az && !aws_db_instance.this.publicly_accessible && aws_db_instance.this.storage_encrypted
    error_message = "Single-AZ lab mode must retain encryption and private access."
  }
}

run "shared_content_guards" {
  command = apply

  module {
    source = "./modules/storage"
  }

  variables {
    name = "storage-test"
    subnet_ids = {
      ap-southeast-2a = "subnet-0123456789abcdef0"
      ap-southeast-2b = "subnet-0123456789abcdef1"
    }
    security_group_id = "sg-0123456789abcdef0"
  }

  assert {
    condition     = aws_efs_file_system.this.encrypted && length(aws_efs_mount_target.this) == 2
    error_message = "EFS must encrypt content at rest and expose a mount target in both AZs."
  }

  assert {
    condition     = one(aws_efs_backup_policy.this.backup_policy).status == "ENABLED"
    error_message = "EFS automatic backup must be enabled."
  }

  assert {
    condition = (
      one(aws_efs_access_point.wordpress.root_directory).path == "/wordpress" &&
      one(aws_efs_access_point.wordpress.posix_user).uid == 48
    )
    error_message = "The WordPress access point must isolate its directory and enforce a non-root POSIX user."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_efs_file_system_policy.this.policy).Statement : statement
      if statement.Sid == "DenyUnencryptedTransport" && statement.Effect == "Deny" && statement.Condition.Bool["aws:SecureTransport"] == "false"
    ]) == 1
    error_message = "EFS must deny unencrypted NFS clients."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_efs_file_system_policy.this.policy).Statement : statement
      if statement.Sid == "DenyOtherAccessPoints" && statement.Effect == "Deny" && statement.Condition.StringNotEquals["elasticfilesystem:AccessPointArn"] == aws_efs_access_point.wordpress.arn
    ]) == 1
    error_message = "EFS clients must use the designated WordPress access point."
  }

  assert {
    condition     = alltrue([for statement in jsondecode(aws_efs_file_system_policy.this.policy).Statement : statement.Effect == "Deny"])
    error_message = "The guardrail policy must not grant anonymous/public access."
  }
}
