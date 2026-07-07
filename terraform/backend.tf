terraform {
  backend "s3" {
    bucket       = "distributed-llm-aws-tf-state"
    key          = "distributed-llm-aws/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
    profile      = "distributed-llm-aws"
  }
}