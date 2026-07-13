#!/bin/bash
# Installs Prometheus, Grafana, and Alertmanager via Docker on the
# monitoring host AMI. Configs are copied in by Packer's file provisioner
# (see monitoring-ami.pkr.hcl) before this script runs.
set -e
 
echo "Installing SSM Agent..."
sudo snap install amazon-ssm-agent --classic || true
sudo snap start amazon-ssm-agent
 
echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
 
echo "Setting up config directories..."
sudo mkdir -p /etc/prometheus /etc/alertmanager
sudo cp /tmp/prometheus.yml /etc/prometheus/prometheus.yml
sudo cp /tmp/alertmanager.yml /etc/alertmanager/alertmanager.yml
 
echo "Starting Prometheus..."
sudo docker run -d --name prometheus --restart always -p 9090:9090 \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
 
echo "Starting Grafana..."
sudo docker run -d --name grafana --restart always -p 3001:3000 \
  grafana/grafana
 
echo "Starting Alertmanager..."
sudo docker run -d --name alertmanager --restart always -p 9093:9093 \
  -v /etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  prom/alertmanager
 
echo "Done!"