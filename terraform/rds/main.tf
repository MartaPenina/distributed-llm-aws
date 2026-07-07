data "terraform_remote_state" "main" {
  backend = "s3"
  config = {
    bucket  = var.main_state_bucket
    key     = var.main_state_key
    region  = var.aws_region
    profile = var.aws_profile
  }
}

module "database" {
  source = "../modules/database"

  project_name      = var.project_name
  environment       = var.environment
  db_subnet_ids     = data.terraform_remote_state.main.outputs.private_db_subnet_ids
  rds_sg_id         = data.terraform_remote_state.main.outputs.rds_sg_id
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
}