# Packer template: builds a custom AWS AMI with Ollama + qwen2.5:3b pre-installed,
# plus node_exporter + Grafana Agent for metrics collection, so ASG instances
# start ready to serve LLM requests and report metrics without manual setup.

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
  ami_description = "Ubuntu 24.04 with Ollama + qwen2.5:3b + Grafana Agent"

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

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-agent.yaml"
    destination = "/tmp/grafana-agent.yaml"
  }

  provisioner "shell" {
    script = "${path.root}/scripts/install-ollama.sh"
  }
}