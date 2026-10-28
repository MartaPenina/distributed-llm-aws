terraform {
  backend "s3" {
    bucket       = "distributed-llm-aws-v2-tf-state-v2-new"
    key          = "distributed-llm-aws-v2/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
    profile      = "distributed-llm-aws-v2"
  }
}