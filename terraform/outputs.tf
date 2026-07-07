output "bastion_public_ip" {
  description = "Bastion Host public IP — use for SSH access"
  value       = module.compute.bastion_public_ip
}

output "alb_dns_name" {
  description = "ALB DNS — open in browser to access Flowise"
  value       = module.compute.alb_dns_name
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.compute.asg_name
}

output "private_db_subnet_ids" {
  description = "Private DB subnet IDs — used by the separate RDS Terraform project"
  value       = module.networking.private_db_subnet_ids
}

output "rds_sg_id" {
  description = "RDS security group ID — used by the separate RDS Terraform project"
  value       = module.security.rds_sg_id
}
