packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_region" {
  default = "eu-central-1"
}

variable "aws_profile" {
  default = "distributed-llm-aws"
}

variable "base_ami" {
  default = "ami-08ea642491f096f83"
}

source "amazon-ebs" "ollama" {
  profile       = var.aws_profile
  region        = var.aws_region
  source_ami    = var.base_ami
  instance_type = "m7i-flex.large"
  ssh_username  = "ubuntu"

  ami_name        = "distributed-llm-aws-ollama-{{timestamp}}"
  ami_description = "Ubuntu 24.04 with Ollama + llama3.1:8b"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Project   = "distributed-llm-aws"
    ManagedBy = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.ollama"]

  provisioner "shell" {
    script = "${path.root}/scripts/install-ollama.sh"
  }
}