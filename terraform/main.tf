# Reads the RDS state (separate S3 backend) so CloudWatch alarms
# in this module can reference the RDS instance identifier as a dimension
data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket  = "distributed-llm-aws-tf-state-v2"
    key     = "distributed-llm-aws/rds/terraform.tfstate"
    region  = "eu-central-1"
    profile = "distributed-llm-aws"
  }
}

module "networking" {
  source = "./modules/networking"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  bastion_allowed_cidrs = var.bastion_allowed_cidrs
}

module "compute" {
  source = "./modules/compute"

  project_name                  = var.project_name
  environment                   = var.environment
  vpc_id                        = module.networking.vpc_id
  public_subnet_ids             = module.networking.public_subnet_ids
  private_app_subnet_ids        = module.networking.private_app_subnet_ids
  bastion_sg_id                 = module.security.bastion_sg_id
  asg_sg_id                     = module.security.asg_sg_id
  bastion_instance_type         = var.bastion_instance_type
  asg_instance_type             = var.asg_instance_type
  asg_min_size                  = var.asg_min_size
  asg_desired_size              = var.asg_desired_size
  asg_max_size                  = var.asg_max_size
  ssh_public_key_path           = var.ssh_public_key_path
  ami_id                        = var.ami_id
  bastion_ami_id                = var.bastion_ami_id
  bastion_instance_profile_name = module.security.bastion_instance_profile_name
  asg_instance_profile_name     = module.security.asg_instance_profile_name
  ollama_internal_alb_sg_id     = module.security.ollama_internal_alb_sg_id
}

module "monitoring" {
  source                  = "./modules/monitoring"
  project_name            = var.project_name
  environment             = var.environment
  alert_email             = var.alert_email
  asg_name                = module.compute.asg_name
  db_instance_id          = data.terraform_remote_state.rds.outputs.db_instance_id
  ollama_internal_alb_arn_suffix          = module.compute.ollama_internal_alb_arn_suffix
  ollama_internal_target_group_arn_suffix = module.compute.ollama_internal_target_group_arn_suffix
}

module "route53" {
  source            = "./modules/route53"
  bastion_public_ip = module.compute.bastion_public_ip
}