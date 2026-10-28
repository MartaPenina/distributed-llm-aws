aws_region   = "eu-central-1"
aws_profile  = "distributed-llm-aws-v2"
environment  = "dev"
project_name = "distributed-llm-aws"

vpc_cidr                 = "10.0.0.0/24"
public_subnet_cidrs      = ["10.0.0.0/27", "10.0.0.32/27"]
private_app_subnet_cidrs = ["10.0.0.64/27", "10.0.0.96/27"]
private_db_subnet_cidrs  = ["10.0.0.128/27", "10.0.0.160/27"]

bastion_instance_type = "m7i-flex.large"
asg_instance_type     = "m7i-flex.large"
asg_min_size          = 2
asg_desired_size      = 2
asg_max_size          = 4
ssh_public_key_path   = "keys/bastion.pub"

db_name           = "llmplatform"
db_username       = "llmadmin"
db_password       = "MONEYmatters"
db_instance_class = "db.t3.micro"

ami_id         = "ami-0f82f32d030e15cd0"
bastion_ami_id = "ami-050f74d0fb0ff4a02"
