output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "asg_sg_id" { value = aws_security_group.asg.id }
output "rds_sg_id" { value = aws_security_group.rds.id }

output "bastion_instance_profile_name" {
  value = aws_iam_instance_profile.bastion.name
}

output "asg_instance_profile_name" {
  value = aws_iam_instance_profile.asg.name
}

output "ollama_internal_alb_sg_id" {
  value = aws_security_group.ollama_internal_alb.id
}