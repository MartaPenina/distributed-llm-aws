output "bastion_public_ip" {
  value = aws_eip.bastion.public_ip
}
output "asg_name" {
  value = aws_autoscaling_group.main.name
}
output "ollama_internal_alb_dns" {
  value = aws_lb.ollama_internal.dns_name
}

output "ollama_internal_alb_arn_suffix" {
  value = aws_lb.ollama_internal.arn_suffix
}
output "ollama_internal_target_group_arn_suffix" {
  value = aws_lb_target_group.ollama_internal.arn_suffix
}