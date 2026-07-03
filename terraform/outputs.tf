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