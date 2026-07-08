#!/bin/bash
# Installs Ollama via Docker (pinned version 0.3.6) + llama3.1:8b
# on Ubuntu AMI for ASG LLM instances.
# Configures Ollama to bind 0.0.0.0 so ALB can reach it.
set -e

echo "Installing SSM Agent..."
sudo snap install amazon-ssm-agent --classic || true
sudo snap start amazon-ssm-agent

echo "Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu

echo "Starting Ollama container (v0.3.6)..."
sudo docker run -d \
  --name ollama \
  --restart always \
  -p 11434:11434 \
  -e OLLAMA_HOST=0.0.0.0 \
  -v ollama:/root/.ollama \
  ollama/ollama:0.3.6

echo "Waiting for Ollama to start..."
sleep 15

echo "Pulling llama3.1:8b model..."
sudo docker exec ollama ollama pull llama3.1:8b

echo "Done!"