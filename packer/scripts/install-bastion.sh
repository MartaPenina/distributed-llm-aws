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

echo "Setting up Alertmanager config template..."
sudo mkdir -p /etc/alertmanager
sudo cp /tmp/alertmanager.yml /etc/alertmanager/alertmanager.yml.template

echo "Creating shared Docker network for monitoring containers..."
sudo docker network create monitoring-net

echo "Starting Prometheus (with remote-write receiver enabled for Grafana Agent)..."
sudo docker run -d --name prometheus --restart always -p 9090:9090 \
  --network monitoring-net \
  -v /etc/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus --config.file=/etc/prometheus/prometheus.yml \
  --web.enable-remote-write-receiver

echo "Setting up Alertmanager systemd service (renders config from SSM at boot)..."
sudo tee /etc/systemd/system/alertmanager.service > /dev/null <<'SVC'
[Unit]
Description=Alertmanager (Docker)
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=-/usr/bin/docker rm -f alertmanager
ExecStart=/bin/bash -c '\
  DISCORD_WEBHOOK=$(aws ssm get-parameter --name "/distributed-llm-aws/dev/discord_webhook_url" --with-decryption --query "Parameter.Value" --output text --region eu-central-1) && \
  sed "s|DISCORD_WEBHOOK_URL_PLACEHOLDER|$DISCORD_WEBHOOK|g" /etc/alertmanager/alertmanager.yml.template | sudo tee /etc/alertmanager/alertmanager.yml > /dev/null && \
  docker run -d --name alertmanager --restart always -p 9093:9093 \
    --network monitoring-net \
    -v /etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml \
    prom/alertmanager --config.file=/etc/alertmanager/alertmanager.yml'

[Install]
WantedBy=multi-user.target
SVC
sudo systemctl daemon-reload
sudo systemctl enable --now alertmanager

echo "Setting up Grafana provisioning (Prometheus data source)..."
sudo mkdir -p /etc/grafana-provisioning/datasources
sudo cp /tmp/grafana-datasource.yaml /etc/grafana-provisioning/datasources/prometheus.yaml

echo "Setting up Grafana provisioning (CloudWatch data source)..."
sudo cp /tmp/grafana-datasource-cloudwatch.yaml /etc/grafana-provisioning/datasources/cloudwatch.yaml

echo "Setting up Grafana dashboard provisioning..."
sudo mkdir -p /etc/grafana-provisioning/dashboards
sudo cp /tmp/grafana-dashboard-provider.yaml /etc/grafana-provisioning/dashboards/provider.yaml
sudo cp /tmp/grafana-dashboard-host-status.json /etc/grafana-provisioning/dashboards/host-status.json
sudo cp /tmp/grafana-dashboard-service-status.json /etc/grafana-provisioning/dashboards/service-status.json
sudo cp /tmp/grafana-dashboard-app-performance.json /etc/grafana-provisioning/dashboards/app-performance.json
sudo cp /tmp/grafana-dashboard-llm-usage.json /etc/grafana-provisioning/dashboards/llm-usage.json
sudo cp /tmp/grafana-dashboard-db-health.json /etc/grafana-provisioning/dashboards/db-health.json

echo "Setting up Grafana systemd service (fetches admin password from SSM at boot)..."
sudo tee /etc/systemd/system/grafana.service > /dev/null <<'SVC'
[Unit]
Description=Grafana (Docker)
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=-/usr/bin/docker rm -f grafana
ExecStart=/bin/bash -c '\
  GRAFANA_PASSWORD=$(aws ssm get-parameter --name "/distributed-llm-aws/dev/grafana_admin_password" --with-decryption --query "Parameter.Value" --output text --region eu-central-1) && \
  docker run -d --name grafana --restart always -p 3001:3000 \
    -v /etc/grafana-provisioning:/etc/grafana/provisioning \
    -e "GF_SECURITY_ADMIN_USER=admin" \
    -e "GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_PASSWORD" \
    grafana/grafana'

[Install]
WantedBy=multi-user.target
SVC
sudo systemctl daemon-reload
sudo systemctl enable --now grafana

echo "Installing CloudWatch Agent..."
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f amazon-cloudwatch-agent.deb

echo "Configuring CloudWatch Agent (memory + disk + procstat for grafana/prometheus/anythingllm)..."
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
sudo cp /tmp/cloudwatch-agent-config-bastion.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Setting up chat request metric cron job..."
sudo cp /tmp/chat-request-metric.sh /usr/local/bin/chat-request-metric.sh
sudo chmod +x /usr/local/bin/chat-request-metric.sh
echo "*/5 * * * * root /usr/local/bin/chat-request-metric.sh >> /var/log/chat-request-metric.log 2>&1" | sudo tee /etc/cron.d/chat-request-metric