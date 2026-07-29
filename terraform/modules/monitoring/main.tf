# SNS topic for alert notifications — CloudWatch/Grafana alarms publish here,
# subscribers (email) receive them.
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "llm-test-ec2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU usage above 80% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "llm-test-ec2-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "EC2 CPU usage below 5% for 15 minutes — possible idle/stuck instance"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

# EN comment: generates one aws_cloudwatch_metric_alarm per entry in var.cloudwatch_alarms
resource "aws_cloudwatch_metric_alarm" "generated" {
  for_each            = var.cloudwatch_alarms
  alarm_name          = each.key
  comparison_operator = each.value.comparison_operator
  evaluation_periods   = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.alarm_description
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = each.value.dimensions
}

# Adds 8 new alarms (RDS storage/cpu/memory, ALB host-count/4xx/5xx) using the reusable for_each pattern — EC2 CPU high/low already exist above 
# as separate resources
locals {
  additional_alarms = {
    "llm-test-db-high-storage" = {
      metric_name         = "FreeStorageSpace"
      namespace           = "AWS/RDS"
      statistic           = "Average"
      period              = 300
      evaluation_periods  = 2
      threshold           = 2000000000 # 2 GB in bytes — alarms when free space drops below this
      comparison_operator = "LessThanThreshold"
      dimensions          = { DBInstanceIdentifier = var.db_instance_id }
      alarm_description   = "RDS free storage below 2GB"
    }
    "llm-test-db-high-cpu" = {
      metric_name         = "CPUUtilization"
      namespace           = "AWS/RDS"
      statistic           = "Average"
      period              = 300
      evaluation_periods  = 2
      threshold           = 80
      comparison_operator = "GreaterThanThreshold"
      dimensions          = { DBInstanceIdentifier = var.db_instance_id }
      alarm_description   = "RDS CPU usage above 80%"
    }
    "llm-test-db-high-memory" = {
      metric_name         = "FreeableMemory"
      namespace           = "AWS/RDS"
      statistic           = "Average"
      period              = 300
      evaluation_periods  = 2
      threshold           = 200000000 # 200 MB in bytes — alarms when free memory drops below this
      comparison_operator = "LessThanThreshold"
      dimensions          = { DBInstanceIdentifier = var.db_instance_id }
      alarm_description   = "RDS freeable memory below 200MB"
    }
    "llm-test-elb-high-host-count" = {
      metric_name         = "HealthyHostCount"
      namespace           = "AWS/ApplicationELB"
      statistic           = "Average"
      period              = 300
      evaluation_periods  = 2
      threshold           = 1
      comparison_operator = "LessThanThreshold"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
        TargetGroup  = var.target_group_arn_suffix
      }
      alarm_description = "Fewer than 1 healthy host behind ALB target group"
    }
    "llm-test-elb-medium-4xx-errors" = {
      metric_name         = "HTTPCode_Target_4XX_Count"
      namespace           = "AWS/ApplicationELB"
      statistic           = "Sum"
      period              = 300
      evaluation_periods  = 2
      threshold           = 10
      comparison_operator = "GreaterThanThreshold"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
      alarm_description = "More than 10 4XX errors in 5 minutes"
    }
    "llm-test-elb-medium-5xx-errors" = {
      metric_name         = "HTTPCode_Target_5XX_Count"
      namespace           = "AWS/ApplicationELB"
      statistic           = "Sum"
      period              = 300
      evaluation_periods  = 2
      threshold           = 5
      comparison_operator = "GreaterThanThreshold"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
      alarm_description = "More than 5 5XX errors in 5 minutes"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "additional" {
  for_each             = local.additional_alarms
  alarm_name           = each.key
  comparison_operator  = each.value.comparison_operator
  evaluation_periods    = each.value.evaluation_periods
  metric_name          = each.value.metric_name
  namespace            = each.value.namespace
  period               = each.value.period
  statistic            = each.value.statistic
  threshold            = each.value.threshold
  alarm_description    = each.value.alarm_description
  alarm_actions        = [aws_sns_topic.alerts.arn]
  ok_actions           = [aws_sns_topic.alerts.arn]
  dimensions           = each.value.dimensions
}