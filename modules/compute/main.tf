data "aws_region" "current" {}

data "aws_ami" "wordpress_base" {
  owners = ["amazon"]

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  bootstrap_settings = {
    region                 = data.aws_region.current.region
    application_secret_arn = var.application_secret_arn
    db_address             = var.db_address
    efs_id                 = var.efs.id
    efs_access_point_id    = var.efs.access_point_id
    site_url               = var.site_url
    admin_email            = var.admin_email
    wordpress_version      = var.downloads.wordpress.version
    wordpress_url          = var.downloads.wordpress.url
    wordpress_sha256       = var.downloads.wordpress.sha256
    rds_ca_url             = var.downloads.rds_ca.url
    rds_ca_sha256          = var.downloads.rds_ca.sha256
  }
}

resource "aws_launch_template" "wordpress" {
  name_prefix   = "${var.name}-"
  image_id      = data.aws_ami.wordpress_base.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.wordpress.name
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [var.security_group_id]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  user_data = base64gzip(templatefile("${path.module}/templates/user-data.sh.tftpl", {
    config_b64      = base64encode(jsonencode(local.bootstrap_settings))
    bootstrap_b64   = base64encode(file("${path.module}/templates/bootstrap.sh"))
    credentials_b64 = base64encode(file("${path.module}/templates/credentials.py"))
    wp_config_b64   = base64encode(file("${path.module}/templates/wp-config.php"))
    installer_b64   = base64encode(file("${path.module}/templates/install-wordpress.php"))
    health_b64      = base64encode(file("${path.module}/templates/health.php"))
    content_b64     = base64encode(file("${path.module}/templates/initialize-content.sh"))
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = var.name, Project = var.name, ManagedBy = "Terraform" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.name}-root", Project = var.name, ManagedBy = "Terraform" }
  }

  depends_on = [aws_iam_role_policy.wordpress]
}

resource "aws_autoscaling_group" "wordpress" {
  name_prefix               = "${var.name}-"
  min_size                  = 1
  max_size                  = 4
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = var.target_group_arns
  health_check_type         = length(var.target_group_arns) > 0 ? "ELB" : "EC2"
  health_check_grace_period = 900
  default_instance_warmup   = 600
  wait_for_capacity_timeout = "0"
  enabled_metrics           = ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]

  launch_template {
    id      = aws_launch_template.wordpress.id
    version = tostring(aws_launch_template.wordpress.latest_version)
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      max_healthy_percentage = 100
      instance_warmup        = 600
    }
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
