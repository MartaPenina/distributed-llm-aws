variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }

variable "bastion_allowed_cidrs" {
  type = list(string)
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID — scopes bastion's DNS-challenge permissions to this zone only"
  type        = string
}