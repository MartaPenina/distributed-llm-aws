#!/bin/bash
set -e

echo "Installing SSM Agent..."
sudo snap install amazon-ssm-agent --classic || true
sudo snap start amazon-ssm-agent

echo "Ensuring SSH server allows agent/TCP forwarding for jump host..."
sudo sed -i 's/^#AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu

echo "Installing AWS CLI..."
sudo apt update
sudo apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

echo "Installing PostgreSQL client..."
sudo apt install -y postgresql-client

echo "Setting up AnythingLLM systemd service..."
sudo cp /tmp/anythingllm.service /etc/systemd/system/anythingllm.service
sudo systemctl daemon-reload
sudo systemctl enable anythingllm.service

echo "Setting up Prometheus config..."
sudo mkdir -p /etc/prometheus
sudo cp /tmp/prometheus.yml /etc/prometheus/prometheus.yml

echo "Starting Prometheus (with remote-write receiver enabled for Grafana Agent)..."
sudo docker run -d --name prometheus --restart always -p 9090:9090 \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus --config.file=/etc/prometheus/prometheus.yml \
  --web.enable-remote-write-receiver

echo "Setting up Grafana provisioning (Prometheus data source)..."
sudo mkdir -p /etc/grafana-provisioning/datasources
sudo cp /tmp/grafana-datasource.yaml /etc/grafana-provisioning/datasources/prometheus.yaml

echo "Setting up Grafana dashboard provisioning..."
sudo mkdir -p /etc/grafana-provisioning/dashboards
sudo cp /tmp/grafana-dashboard-provider.yaml /etc/grafana-provisioning/dashboards/provider.yaml
sudo cp /tmp/grafana-dashboard-host-status.json /etc/grafana-provisioning/dashboards/host-status.json

echo "Starting Grafana (host port 3001, since 3000 is taken by AnythingLLM)..."
sudo docker run -d --name grafana --restart always -p 3001:3000 \
  -v /etc/grafana-provisioning:/etc/grafana/provisioning \
  grafana/grafana