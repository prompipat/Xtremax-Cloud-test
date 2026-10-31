mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }
  mock_data "aws_region" {
    defaults = { region = "ap-southeast-2" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0", latest_version = 1 }
  }
}

variables {
  name                   = "compute-test"
  ami_id                 = "ami-0123456789abcdef0"
  subnet_ids             = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  security_group_id      = "sg-0123456789abcdef0"
  application_secret_arn = "arn:aws:secretsmanager:ap-southeast-2:123456789012:secret:application-test"
  db_address             = "database.example.internal"
  efs = {
    id               = "fs-0123456789abcdef0"
    arn              = "arn:aws:elasticfilesystem:ap-southeast-2:123456789012:file-system/fs-0123456789abcdef0"
    access_point_id  = "fsap-0123456789abcdef0"
    access_point_arn = "arn:aws:elasticfilesystem:ap-southeast-2:123456789012:access-point/fsap-0123456789abcdef0"
  }
  downloads = {
    wordpress = { version = "7.1.4", url = "https://wordpress.org/wordpress-7.1.4.tar.gz", sha256 = "test-hash" }
    rds_ca    = { url = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem", sha256 = "test-hash" }
  }
  site_url          = "https://school.example.com"
  admin_email       = "admin@example.com"
  target_group_arns = ["arn:aws:elasticloadbalancing:ap-southeast-2:123456789012:targetgroup/test/0123456789abcdef"]
}

run "fleet_security_and_scaling" {
  command = apply
  module {
    source = "./modules/compute"
  }

  override_resource {
    target = aws_autoscaling_policy.cpu["out"]
    values = { arn = "arn:aws:autoscaling:ap-southeast-2:123456789012:scalingPolicy:01234567-89ab-cdef-0123-456789abcdef:autoScalingGroupName/test:policyName/out" }
  }

  override_resource {
    target = aws_autoscaling_policy.cpu["in"]
    values = { arn = "arn:aws:autoscaling:ap-southeast-2:123456789012:scalingPolicy:11234567-89ab-cdef-0123-456789abcdef:autoScalingGroupName/test:policyName/in" }
  }

  assert {
    condition = (
      aws_autoscaling_group.wordpress.min_size == 1 &&
      aws_autoscaling_group.wordpress.max_size == 4 &&
      aws_autoscaling_group.wordpress.desired_capacity == 2 &&
      aws_autoscaling_group.wordpress.health_check_type == "ELB" &&
      one(one(aws_autoscaling_group.wordpress.instance_refresh).preferences).max_healthy_percentage == 100 &&
      one(aws_autoscaling_group.wordpress.launch_template).version == "1"
    )
    error_message = "The attached fleet must use min 1/max 4, ELB health checks and a numeric launch-template version."
  }

  assert {
    condition = (
      one(aws_launch_template.wordpress.metadata_options).http_tokens == "required" &&
      one(one(aws_launch_template.wordpress.block_device_mappings).ebs).encrypted &&
      !one(aws_launch_template.wordpress.network_interfaces).associate_public_ip_address
    )
    error_message = "Instances must require IMDSv2, encrypted root disks and private-only network interfaces."
  }

  assert {
    condition = alltrue([
      for alarm in aws_cloudwatch_metric_alarm.cpu :
      alarm.period == 300 && alarm.evaluation_periods == 6 && alarm.datapoints_to_alarm == 6 && alarm.treat_missing_data == "notBreaching"
    ])
    error_message = "CPU actions must require six breaching 5-minute data points and avoid scaling on missing data."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.cpu["out"].threshold == 80 &&
      aws_cloudwatch_metric_alarm.cpu["out"].comparison_operator == "GreaterThanThreshold" &&
      aws_cloudwatch_metric_alarm.cpu["in"].threshold == 40 &&
      aws_cloudwatch_metric_alarm.cpu["in"].comparison_operator == "LessThanThreshold" &&
      one(aws_autoscaling_policy.cpu["out"].step_adjustment).scaling_adjustment == 1 &&
      one(aws_autoscaling_policy.cpu["in"].step_adjustment).scaling_adjustment == -1
    )
    error_message = "Scaling must add one above 80 and remove one below 40, with strict threshold comparisons."
  }

  assert {
    condition = alltrue([
      for direction in ["in", "out"] :
      contains(aws_cloudwatch_metric_alarm.cpu[direction].alarm_actions, aws_autoscaling_policy.cpu[direction].arn) &&
      aws_cloudwatch_metric_alarm.cpu[direction].dimensions.AutoScalingGroupName == aws_autoscaling_group.wordpress.name
    ])
    error_message = "Alarms must target the matching policy and aggregate the intended ASG."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.wordpress.policy).Statement : statement
      if statement.Sid == "ReadApplicationSecret" && statement.Action == "secretsmanager:GetSecretValue" && statement.Resource == var.application_secret_arn
    ]) == 1
    error_message = "The runtime role must read only the application secret, never the RDS master secret."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.wordpress.policy).Statement : statement
      if statement.Sid == "MountWordPressContent" && statement.Resource == var.efs.arn && statement.Condition.StringEquals["elasticfilesystem:AccessPointArn"] == var.efs.access_point_arn
    ]) == 1
    error_message = "EFS client permissions must be scoped to this filesystem and access point."
  }
}

run "reject_capacity_above_four" {
  command = plan
  module {
    source = "./modules/compute"
  }
  variables {
    desired_capacity = 5
  }
  expect_failures = [var.desired_capacity]
}
