#!/bin/bash
# Installs Ollama + llama3.1:8b on Ubuntu AMI for ASG LLM instances.
# Configures Ollama to bind 0.0.0.0 (not 127.0.0.1) so ALB can reach it.
set -e

echo "Installing SSM Agent..."
sudo snap install amazon-ssm-agent --classic || true
sudo snap start amazon-ssm-agent

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu

echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# Default Ollama binds to 127.0.0.1 — override so ALB health checks and Flowise can connect
echo "Configuring Ollama host binding..."
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
sudo systemctl daemon-reload
sudo systemctl restart ollama

echo "Waiting for Ollama to start..."
sleep 10

echo "Pulling llama3.1:8b model..."
ollama pull llama3.1:8b

echo "Done!"