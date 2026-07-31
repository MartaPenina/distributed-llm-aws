terraform {
  backend "s3" {
    bucket       = "distributed-llm-aws-tf-state-v2"
    key          = "distributed-llm-aws/rds/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    profile      = "distributed-llm-aws"
    encrypt      = true
  }
}
