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

source "amazon-ebs" "bastion" {
  profile       = var.aws_profile
  region        = var.aws_region
  source_ami    = var.base_ami
  instance_type = "m7i-flex.large"
  ssh_username  = "ubuntu"

  ami_name        = "distributed-llm-aws-bastion-{{timestamp}}"
  ami_description = "Ubuntu 24.04 Bastion Host with SSM Agent"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Project   = "distributed-llm-aws"
    ManagedBy = "packer"
    Type      = "bastion"
  }
}

build {
  sources = ["source.amazon-ebs.bastion"]

  # Copies flowise.service from local disk to the temp instance's /tmp,
  # so install-bastion.sh can move it into /etc/systemd/system/ afterward.
  provisioner "file" {
    source      = "${path.root}/scripts/flowise.service"
    destination = "/tmp/flowise.service"
  }

  provisioner "shell" {
    script = "${path.root}/scripts/install-bastion.sh"
  }
}
