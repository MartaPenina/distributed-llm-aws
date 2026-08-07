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
    volume_size           = 25
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Project     = "distributed-llm-aws"
    ManagedBy   = "packer"
    Type        = "bastion"
    BuildDate   = "{{timestamp}}"
    BuildSource = "{{build_name}}"
  }
}

build {
  sources = ["source.amazon-ebs.bastion"]

  provisioner "file" {
    source      = "${path.root}/scripts/anythingllm.service"
    destination = "/tmp/anythingllm.service"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/prometheus.yml"
    destination = "/tmp/prometheus.yml"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/alertmanager.yml"
    destination = "/tmp/alertmanager.yml"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-datasource.yaml"
    destination = "/tmp/grafana-datasource.yaml"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-dashboard-provider.yaml"
    destination = "/tmp/grafana-dashboard-provider.yaml"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-dashboard-host-status.json"
    destination = "/tmp/grafana-dashboard-host-status.json"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-dashboard-app-performance.json"
    destination = "/tmp/grafana-dashboard-app-performance.json"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-dashboard-llm-usage.json"
    destination = "/tmp/grafana-dashboard-llm-usage.json"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-dashboard-db-health.json"
    destination = "/tmp/grafana-dashboard-db-health.json"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-dashboard-service-status.json"
    destination = "/tmp/grafana-dashboard-service-status.json"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-alert-rules.yaml"
    destination = "/tmp/grafana-alert-rules.yaml"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-contact-points.yaml"
    destination = "/tmp/grafana-contact-points.yaml"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/cloudwatch-agent-config-bastion.json"
    destination = "/tmp/cloudwatch-agent-config-bastion.json"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/grafana-datasource-cloudwatch.yaml"
    destination = "/tmp/grafana-datasource-cloudwatch.yaml"
  }

  provisioner "file" {
    source      = "${path.root}/scripts/chat-request-metric.sh"
    destination = "/tmp/chat-request-metric.sh"
  }

  provisioner "shell" {
    script = "${path.root}/scripts/install-bastion.sh"
  }
}
