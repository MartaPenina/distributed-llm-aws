# Packer template: builds a custom AWS AMI with Prometheus, Grafana, and
# Alertmanager pre-installed, so the monitoring host starts ready to collect
# metrics and serve dashboards without manual setup on every launch.

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

source "amazon-ebs" "monitoring" {
  profile       = var.aws_profile
  region        = var.aws_region
  source_ami    = var.base_ami
  instance_type = "m7i-flex.large"
  ssh_username  = "ubuntu"

  ami_name        = "distributed-llm-aws-monitoring-{{timestamp}}"
  ami_description = "Ubuntu 24.04 with Prometheus + Grafana + Alertmanager"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Project     = "distributed-llm-aws"
    ManagedBy   = "packer"
    Type        = "monitoring"
    BuildDate   = "{{timestamp}}"
    BuildSource = "{{build_name}}"
  }
}

build {
  sources = ["source.amazon-ebs.monitoring"]

  # Copies pre-written config files so install-monitoring.sh can move them
  # into place afterward — same pattern as flowise.service/anythingllm.service.
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
    source      = "${path.root}/scripts/grafana-datasource-cloudwatch.yaml"
    destination = "/tmp/grafana-datasource-cloudwatch.yaml"
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
    source      = "${path.root}/scripts/grafana-dashboard-service-status.json"
    destination = "/tmp/grafana-dashboard-service-status.json"
  }
  provisioner "file" {
    source      = "${path.root}/scripts/cloudwatch-agent-config-bastion.json"
    destination = "/tmp/cloudwatch-agent-config-bastion.json"
  }

  provisioner "shell" {
    script = "${path.root}/scripts/install-monitoring.sh"
  }
}
