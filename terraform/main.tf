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

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  my_ip        = var.my_ip
}

module "compute" {
  source = "./modules/compute"

  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.networking.vpc_id
  public_subnet_ids        = module.networking.public_subnet_ids
  private_app_subnet_ids   = module.networking.private_app_subnet_ids
  bastion_sg_id            = module.security.bastion_sg_id
  asg_sg_id                = module.security.asg_sg_id
  alb_sg_id                = module.security.alb_sg_id
  bastion_instance_type    = var.bastion_instance_type
  asg_instance_type        = var.asg_instance_type
  asg_min_size             = var.asg_min_size
  asg_desired_size         = var.asg_desired_size
  asg_max_size             = var.asg_max_size
  ssh_public_key_path      = var.ssh_public_key_path
}

module "database" {
  source = "./modules/database"

  project_name      = var.project_name
  environment       = var.environment
  db_subnet_ids     = module.networking.private_db_subnet_ids
  rds_sg_id         = module.security.rds_sg_id
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  db_instance_class = var.db_instance_class
}