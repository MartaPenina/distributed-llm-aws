variable "aws_region" { type = string }
variable "aws_profile" { type = string }
variable "project_name" { type = string }
variable "environment" { type = string }

variable "main_state_bucket" { type = string }
variable "main_state_key" { type = string }

variable "db_name" { type = string }
variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_instance_class" { type = string }

variable "alert_email" {
  type        = string
  description = "Email address to receive CloudWatch/Grafana alert notifications"
}