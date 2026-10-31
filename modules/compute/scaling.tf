locals {
  scaling = {
    out = { threshold = 80, operator = "GreaterThanThreshold", adjustment = 1 }
    in  = { threshold = 40, operator = "LessThanThreshold", adjustment = -1 }
  }
}

resource "aws_autoscaling_policy" "cpu" {
  for_each = local.scaling

  name                      = "${var.name}-cpu-${each.key}"
  autoscaling_group_name    = aws_autoscaling_group.wordpress.name
  policy_type               = "StepScaling"
  adjustment_type           = "ChangeInCapacity"
  metric_aggregation_type   = "Average"
  estimated_instance_warmup = 600

  step_adjustment {
    metric_interval_lower_bound = each.key == "out" ? 0 : null
    metric_interval_upper_bound = each.key == "in" ? 0 : null
    scaling_adjustment          = each.value.adjustment
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each = local.scaling

  alarm_name          = "${var.name}-cpu-${each.key}"
  alarm_description   = "ASG average CPU ${each.value.operator} ${each.value.threshold}% for six 300-second evaluation periods"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  unit                = "Percent"
  period              = 300
  evaluation_periods  = 6
  datapoints_to_alarm = 6
  threshold           = each.value.threshold
  comparison_operator = each.value.operator
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_autoscaling_policy.cpu[each.key].arn]
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.wordpress.name }
}
