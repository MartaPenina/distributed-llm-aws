variable "project_name" { type = string }
variable "environment"  { type = string }
variable "vpc_id"       { type = string }

variable "bastion_allowed_cidrs" {
  type = list(string)
}