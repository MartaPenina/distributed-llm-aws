variable "project_name"         { type = string }
variable "environment"          { type = string }
variable "public_subnet_ids"    { type = list(string) }
variable "private_app_subnet_ids" { type = list(string) }
variable "bastion_sg_id"        { type = string }
variable "asg_sg_id"            { type = string }
variable "alb_sg_id"            { type = string }
variable "vpc_id"               { type = string }
variable "bastion_instance_type" { type = string }
variable "asg_instance_type"    { type = string }
variable "asg_min_size"         { type = number }
variable "asg_desired_size"     { type = number }
variable "asg_max_size"         { type = number }
variable "ssh_public_key_path"  { type = string }
variable "ami_id" {
  type        = string
  description = "AMI ID from Packer build — replace after Packer step"
  default     = "ami-00cf59bc9978310fd" # Ubuntu 24.04 eu-central-1 placeholder
}