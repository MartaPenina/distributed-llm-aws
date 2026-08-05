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

echo "Setting up Grafana provisioning..."
sudo mkdir -p /etc/grafana/provisioning/datasources
sudo mkdir -p /etc/grafana/provisioning/dashboards
sudo mkdir -p /etc/grafana/dashboards

sudo cp /tmp/grafana-datasource.yaml /etc/grafana/provisioning/datasources/
sudo cp /tmp/grafana-datasource-cloudwatch.yaml /etc/grafana/provisioning/datasources/
sudo cp /tmp/grafana-dashboard-provider.yaml /etc/grafana/provisioning/dashboards/
sudo cp /tmp/grafana-dashboard-host-status.json /etc/grafana/dashboards/
sudo cp /tmp/grafana-dashboard-service-status.json /etc/grafana/dashboards/
 
echo "Starting Grafana..."
sudo docker run -d --name grafana --restart always -p 3001:3000 \
  -v /etc/grafana/provisioning:/etc/grafana/provisioning \
  -v /etc/grafana/dashboards:/etc/grafana/dashboards \
  grafana/grafana
 
echo "Starting Alertmanager..."
sudo docker run -d --name alertmanager --restart always -p 9093:9093 \
  -v /etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
  prom/alertmanager

echo "Installing CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f amazon-cloudwatch-agent.deb

echo "Configuring CloudWatch Agent (memory + disk + service metrics)..."
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo cp /tmp/cloudwatch-agent-config-bastion.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
 
echo "Done!"