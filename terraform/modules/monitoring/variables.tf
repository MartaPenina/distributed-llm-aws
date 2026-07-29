variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address to receive CloudWatch/Grafana alert notifications"
}

variable "asg_name" {
  type        = string
  description = "Auto Scaling Group name for CloudWatch alarm dimensions"
}

variable "cloudwatch_alarms" {
  description = "Map of additional CloudWatch alarms (EC2 mem/disk, RDS, ALB)"
  type = map(object({
    metric_name         = string
    namespace           = string
    statistic           = string
    period              = number
    evaluation_periods  = number
    threshold           = number
    comparison_operator = string
    dimensions          = map(string)
    alarm_description   = string
  }))
  default = {}
}

variable "db_instance_id" {
  description = "RDS instance identifier for CloudWatch alarm dimensions"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB arn_suffix for CloudWatch alarm dimensions"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group arn_suffix for CloudWatch alarm dimensions"
  type        = string
}