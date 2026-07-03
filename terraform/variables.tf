variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "distributed-llm-aws"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for naming and tagging"
  type        = string
  default     = "distributed-llm-aws"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/24"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/27", "10.0.0.32/27"]
}

variable "private_app_subnet_cidrs" {
  description = "Private app subnet CIDRs for ASG"
  type        = list(string)
  default     = ["10.0.0.64/27", "10.0.0.96/27"]
}

variable "private_db_subnet_cidrs" {
  description = "Private DB subnet CIDRs for RDS"
  type        = list(string)
  default     = ["10.0.0.128/27", "10.0.0.160/27"]
}

variable "bastion_instance_type" {
  description = "Instance type for Bastion Host"
  type        = string
  default     = "t3.micro"
}

variable "asg_instance_type" {
  description = "Instance type for ASG Ollama instances"
  type        = string
  default     = "m7i-flex.large"
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_desired_size" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "my_ip" {
  description = "Your public IP for Bastion SSH access (x.x.x.x/32)"
  type        = string
  sensitive   = true
}

variable "db_name" {
  type    = string
  default = "llmplatform"
}

variable "db_username" {
  type      = string
  default   = "llmadmin"
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.medium"
}