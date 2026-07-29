#!/bin/bash
# Installs Ollama via Docker (pinned version 0.3.6) + qwen2.5:3b
# on Ubuntu AMI for ASG LLM instances. Switched from llama3.1:8b (OOM) and
# phi3:mini (ran at ~99% of the 7GB memory limit under Agent mode, no
# headroom) after local docker-compose testing with a 7GB memory cap.
# qwen2.5:3b stays around 3GB / ~42% of the limit even under sustained load —
# confirmed safe on m7i-flex.large instances (7.6GB total, ~7GB available).
# Configures Ollama to bind 0.0.0.0 so ALB can reach it.
set -e

echo "Installing SSM Agent..."
sudo snap install amazon-ssm-agent --classic || true
sudo snap start amazon-ssm-agent

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu

echo "Starting Ollama container (v0.3.6)..."
sudo docker run -d --name ollama --restart always -p 11434:11434 -e OLLAMA_HOST=0.0.0.0 -v ollama:/root/.ollama ollama/ollama:0.3.6

echo "Waiting for Ollama to start..."
sleep 15

echo "Pulling qwen2.5:3b model..."
sudo docker exec ollama ollama pull qwen2.5:3b

# node_exporter exposes this host's CPU/RAM/disk metrics on :9100 —
# Grafana Agent (installed below) reads from it and forwards to Prometheus.
echo "Installing node_exporter (system metrics source for Grafana Agent)..."
NODE_EXPORTER_VERSION="1.8.2"
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*

sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'SVC'
[Unit]
Description=Node Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
SVC

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

echo "Installing Grafana Agent..."
sudo apt-get update
sudo apt-get install -y gpg
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install -y grafana-agent

echo "Configuring and starting Grafana Agent..."
sudo cp /tmp/grafana-agent.yaml /etc/grafana-agent.yaml
sudo systemctl enable --now grafana-agent

echo "Done!"